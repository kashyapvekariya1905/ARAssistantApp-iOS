import ARKit
import UIKit

class CameraStreamManager: NSObject, ObservableObject {
    private var frameTimer: Timer?
    private let targetFPS: Double = 15.0
    private var lastFrameTime: TimeInterval = 0
    
    @Published var isStreaming = false
    
    // Quality settings
    private let jpegCompressionQuality: CGFloat = 0.5
    private let maxImageWidth: CGFloat = 640
    
    override init() {
        super.init()
    }
    
    func startStreaming(from sceneView: ARSCNView) {
        // FIXED: Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.isStreaming = true
        }
        
        // Start frame capture timer on main thread
        DispatchQueue.main.async {
            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.targetFPS, repeats: true) { [weak self] _ in
                self?.captureAndSendFrame(from: sceneView)
            }
        }
    }
    
    func stopStreaming() {
        // FIXED: Ensure UI updates happen on main thread
        DispatchQueue.main.async {
            self.isStreaming = false
            self.frameTimer?.invalidate()
            self.frameTimer = nil
        }
    }
    
    private func captureAndSendFrame(from sceneView: ARSCNView) {
        // Capture current frame
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        // Throttle frame rate
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFrameTime < (1.0 / targetFPS) {
            return
        }
        lastFrameTime = currentTime
        
        // Process image data on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Convert CVPixelBuffer to UIImage
            let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
            let context = CIContext()
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            var uiImage = UIImage(cgImage: cgImage)
            
            // Rotate image to correct orientation
            uiImage = uiImage.fixedOrientation()
            
            // Resize image for efficient transmission
            if let resizedImage = uiImage.resized(toWidth: self.maxImageWidth),
               let imageData = resizedImage.jpegData(compressionQuality: self.jpegCompressionQuality) {
                
                // Send via WebSocket
                SocketManager.shared.sendImageData(imageData)
            }
        }
    }
}

// UIImage extensions for processing
extension UIImage {
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
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










