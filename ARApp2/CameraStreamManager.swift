import ARKit
import UIKit

class CameraStreamManager: NSObject, ObservableObject {
    private var frameTimer: Timer?
    private let targetFPS: Double = 15.0
    private var lastFrameTime: TimeInterval = 0
    
    @Published var isStreaming = false
    
    private let jpegCompressionQuality: CGFloat = 0.5
    private let maxImageWidth: CGFloat = 640
    
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
            let context = CIContext()
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            let deviceOrientation = UIDevice.current.orientation
            let imageOrientation = self.getImageOrientation(deviceOrientation: deviceOrientation)
            var uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
            
            uiImage = uiImage.fixedOrientation()
            
            if let resizedImage = uiImage.resized(toWidth: self.maxImageWidth),
               let imageData = resizedImage.jpegData(compressionQuality: self.jpegCompressionQuality) {
                
                SocketManager.shared.sendImageData(imageData)
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
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}
