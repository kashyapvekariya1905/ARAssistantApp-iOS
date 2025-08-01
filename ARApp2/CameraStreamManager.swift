
import ARKit
import UIKit

class CameraStreamManager: NSObject, ObservableObject {
    private var frameTimer: Timer?
    private let targetFPS: Double = 30.0
    private var lastFrameTime: TimeInterval = 0
    
    @Published var isStreaming = false
    
    private let baseJpegQuality: CGFloat = 0.7
    private let maxImageWidth: CGFloat = 854
    private let maxChunkSize = 65536
    private let adaptiveQualityEnabled = true
    private var currentQuality: CGFloat = 0.7
    private var networkCondition: NetworkCondition = .good
    private var frameSkipCounter = 0
    private var sendTimes: [TimeInterval] = []
    
    enum NetworkCondition {
        case excellent, good, fair, poor
        
        var maxSize: Int {
            switch self {
            case .excellent: return 131072
            case .good: return 65536
            case .fair: return 32768
            case .poor: return 16384
            }
        }
        
        var targetQuality: CGFloat {
            switch self {
            case .excellent: return 0.8
            case .good: return 0.7
            case .fair: return 0.5
            case .poor: return 0.3
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    func startStreaming(from sceneView: ARSCNView) {
        DispatchQueue.main.async {
            self.isStreaming = true
        }
        
        DispatchQueue.main.async {
            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.targetFPS, repeats: true) { [weak self] _ in
                self?.captureAndSendFrame(from: sceneView)
            }
        }
    }
    
    func stopStreaming() {
        DispatchQueue.main.async {
            self.isStreaming = false
            self.frameTimer?.invalidate()
            self.frameTimer = nil
        }
    }
    
    private func captureAndSendFrame(from sceneView: ARSCNView) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFrameTime < (1.0 / targetFPS) {
            return
        }
        lastFrameTime = currentTime
        
        if adaptiveQualityEnabled {
            adaptNetworkQuality()
        }
        
        let shouldSkipFrame = frameSkipCounter % getFrameSkipRatio() != 0
        frameSkipCounter += 1
        
        if shouldSkipFrame && networkCondition == .poor {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CACurrentMediaTime()
            
            let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
            let context = CIContext(options: [
                .useSoftwareRenderer: false,
                .priorityRequestLow: false
            ])
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let deviceOrientation = UIDevice.current.orientation
            let imageOrientation = self.getImageOrientation(deviceOrientation: deviceOrientation)
            var uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
            
            uiImage = uiImage.fixedOrientation()
            
            let targetWidth = self.getAdaptiveImageWidth()
            if let resizedImage = uiImage.resized(toWidth: targetWidth) {
                var imageData: Data?
                var quality = self.currentQuality
                let maxAllowedSize = self.networkCondition.maxSize
                
                repeat {
                    imageData = resizedImage.jpegData(compressionQuality: quality)
                    if let data = imageData, data.count <= maxAllowedSize {
                        break
                    }
                    quality -= 0.05
                } while quality > 0.15
                
                if let finalImageData = imageData {
                    let processTime = CACurrentMediaTime() - startTime
                    self.recordSendTime(processTime)
                    
                    if finalImageData.count <= 32768 {
                        SocketManager.shared.sendImageData(finalImageData)
                    } else {
                        self.sendChunkedData(finalImageData, type: "IMAGE")
                    }
                }
            }
        }
    }
    
    private func getAdaptiveImageWidth() -> CGFloat {
        switch networkCondition {
        case .excellent: return 1080
        case .good: return 854
        case .fair: return 640
        case .poor: return 480
        }
    }
    
    private func getFrameSkipRatio() -> Int {
        switch networkCondition {
        case .excellent: return 1
        case .good: return 1
        case .fair: return 2
        case .poor: return 3
        }
    }
    
    private func recordSendTime(_ time: TimeInterval) {
        sendTimes.append(time)
        if sendTimes.count > 10 {
            sendTimes.removeFirst()
        }
    }
    
    private func adaptNetworkQuality() {
        guard sendTimes.count >= 5 else { return }
        
        let avgTime = sendTimes.reduce(0, +) / Double(sendTimes.count)
        
        switch avgTime {
        case 0..<0.03:
            networkCondition = .excellent
        case 0.03..<0.06:
            networkCondition = .good
        case 0.06..<0.12:
            networkCondition = .fair
        default:
            networkCondition = .poor
        }
        
        currentQuality = networkCondition.targetQuality
    }
    
    private func sendChunkedData(_ data: Data, type: String) {
        let chunkId = UUID().uuidString
        let totalChunks = (data.count + maxChunkSize - 1) / maxChunkSize
        
        for i in 0..<totalChunks {
            let startIndex = i * maxChunkSize
            let endIndex = min(startIndex + maxChunkSize, data.count)
            let chunk = data.subdata(in: startIndex..<endIndex)
            
            let chunkMessage: [String: Any] = [
                "type": "CHUNK",
                "dataType": type,
                "chunkId": chunkId,
                "chunkIndex": i,
                "totalChunks": totalChunks,
                "data": chunk.base64EncodedString()
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: chunkMessage) {
                SocketManager.shared.sendRawData(jsonData)
            }
        }
    }
    
    private func getImageOrientation(deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        guard let cgImage = cgImage,
              let colorSpace = cgImage.colorSpace,
              let context = CGContext(data: nil,
                                    width: Int(size.width),
                                    height: Int(size.height),
                                    bitsPerComponent: cgImage.bitsPerComponent,
                                    bytesPerRow: 0,
                                    space: colorSpace,
                                    bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let newCGImage = context.makeImage() else { return self }
        return UIImage(cgImage: newCGImage)
    }
    
    func resized(toWidth width: CGFloat) -> UIImage? {
        let scale = width / size.width
        let newHeight = size.height * scale
        let newSize = CGSize(width: width, height: newHeight)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
