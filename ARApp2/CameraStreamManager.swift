//
//import ARKit
//import UIKit
//
//class CameraStreamManager: NSObject, ObservableObject {
//    private var frameTimer: Timer?
//    private let targetFPS: Double = 30.0
//    private var lastFrameTime: TimeInterval = 0
//    
//    @Published var isStreaming = false
//    
//    private let baseJpegQuality: CGFloat = 0.7
//    private let maxImageWidth: CGFloat = 854
//    private let maxChunkSize = 65536
//    private let adaptiveQualityEnabled = true
//    private var currentQuality: CGFloat = 0.7
//    private var networkCondition: NetworkCondition = .good
//    private var frameSkipCounter = 0
//    private var sendTimes: [TimeInterval] = []
//    
//    enum NetworkCondition {
//        case excellent, good, fair, poor
//        
//        var maxSize: Int {
//            switch self {
//            case .excellent: return 131072
//            case .good: return 65536
//            case .fair: return 32768
//            case .poor: return 16384
//            }
//        }
//        
//        var targetQuality: CGFloat {
//            switch self {
//            case .excellent: return 0.8
//            case .good: return 0.7
//            case .fair: return 0.5
//            case .poor: return 0.3
//            }
//        }
//    }
//    
//    override init() {
//        super.init()
//    }
//    
//    func startStreaming(from sceneView: ARSCNView) {
//        DispatchQueue.main.async {
//            self.isStreaming = true
//        }
//        
//        DispatchQueue.main.async {
//            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.targetFPS, repeats: true) { [weak self] _ in
//                self?.captureAndSendFrame(from: sceneView)
//            }
//        }
//    }
//    
//    func stopStreaming() {
//        DispatchQueue.main.async {
//            self.isStreaming = false
//            self.frameTimer?.invalidate()
//            self.frameTimer = nil
//        }
//    }
//    
//    private func captureAndSendFrame(from sceneView: ARSCNView) {
//        guard let currentFrame = sceneView.session.currentFrame else { return }
//        
//        let currentTime = CACurrentMediaTime()
//        if currentTime - lastFrameTime < (1.0 / targetFPS) {
//            return
//        }
//        lastFrameTime = currentTime
//        
//        if adaptiveQualityEnabled {
//            adaptNetworkQuality()
//        }
//        
//        let shouldSkipFrame = frameSkipCounter % getFrameSkipRatio() != 0
//        frameSkipCounter += 1
//        
//        if shouldSkipFrame && networkCondition == .poor {
//            return
//        }
//        
//        DispatchQueue.global(qos: .userInitiated).async {
//            let startTime = CACurrentMediaTime()
//            
//            let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
//            let context = CIContext(options: [
//                .useSoftwareRenderer: false,
//                .priorityRequestLow: false
//            ])
//            
//            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
//            
//            let deviceOrientation = UIDevice.current.orientation
//            let imageOrientation = self.getImageOrientation(deviceOrientation: deviceOrientation)
//            var uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
//            
//            uiImage = uiImage.fixedOrientation()
//            
//            let targetWidth = self.getAdaptiveImageWidth()
//            if let resizedImage = uiImage.resized(toWidth: targetWidth) {
//                var imageData: Data?
//                var quality = self.currentQuality
//                let maxAllowedSize = self.networkCondition.maxSize
//                
//                repeat {
//                    imageData = resizedImage.jpegData(compressionQuality: quality)
//                    if let data = imageData, data.count <= maxAllowedSize {
//                        break
//                    }
//                    quality -= 0.05
//                } while quality > 0.15
//                
//                if let finalImageData = imageData {
//                    let processTime = CACurrentMediaTime() - startTime
//                    self.recordSendTime(processTime)
//                    
//                    if finalImageData.count <= 32768 {
//                        SocketManager.shared.sendImageData(finalImageData)
//                    } else {
//                        self.sendChunkedData(finalImageData, type: "IMAGE")
//                    }
//                }
//            }
//        }
//    }
//    
//    private func getAdaptiveImageWidth() -> CGFloat {
//        switch networkCondition {
//        case .excellent: return 1080
//        case .good: return 854
//        case .fair: return 640
//        case .poor: return 480
//        }
//    }
//    
//    private func getFrameSkipRatio() -> Int {
//        switch networkCondition {
//        case .excellent: return 1
//        case .good: return 1
//        case .fair: return 2
//        case .poor: return 3
//        }
//    }
//    
//    private func recordSendTime(_ time: TimeInterval) {
//        sendTimes.append(time)
//        if sendTimes.count > 10 {
//            sendTimes.removeFirst()
//        }
//    }
//    
//    private func adaptNetworkQuality() {
//        guard sendTimes.count >= 5 else { return }
//        
//        let avgTime = sendTimes.reduce(0, +) / Double(sendTimes.count)
//        
//        switch avgTime {
//        case 0..<0.03:
//            networkCondition = .excellent
//        case 0.03..<0.06:
//            networkCondition = .good
//        case 0.06..<0.12:
//            networkCondition = .fair
//        default:
//            networkCondition = .poor
//        }
//        
//        currentQuality = networkCondition.targetQuality
//    }
//    
//    private func sendChunkedData(_ data: Data, type: String) {
//        let chunkId = UUID().uuidString
//        let totalChunks = (data.count + maxChunkSize - 1) / maxChunkSize
//        
//        for i in 0..<totalChunks {
//            let startIndex = i * maxChunkSize
//            let endIndex = min(startIndex + maxChunkSize, data.count)
//            let chunk = data.subdata(in: startIndex..<endIndex)
//            
//            let chunkMessage: [String: Any] = [
//                "type": "CHUNK",
//                "dataType": type,
//                "chunkId": chunkId,
//                "chunkIndex": i,
//                "totalChunks": totalChunks,
//                "data": chunk.base64EncodedString()
//            ]
//            
//            if let jsonData = try? JSONSerialization.data(withJSONObject: chunkMessage) {
//                SocketManager.shared.sendRawData(jsonData)
//            }
//        }
//    }
//    
//    private func getImageOrientation(deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
//        switch deviceOrientation {
//        case .portrait:
//            return .right
//        case .portraitUpsideDown:
//            return .left
//        case .landscapeLeft:
//            return .up
//        case .landscapeRight:
//            return .down
//        default:
//            return .right
//        }
//    }
//}
//
//extension UIImage {
//    func fixedOrientation() -> UIImage {
//        guard imageOrientation != .up else { return self }
//        
//        var transform = CGAffineTransform.identity
//        
//        switch imageOrientation {
//        case .down, .downMirrored:
//            transform = transform.translatedBy(x: size.width, y: size.height)
//            transform = transform.rotated(by: .pi)
//        case .left, .leftMirrored:
//            transform = transform.translatedBy(x: size.width, y: 0)
//            transform = transform.rotated(by: .pi / 2)
//        case .right, .rightMirrored:
//            transform = transform.translatedBy(x: 0, y: size.height)
//            transform = transform.rotated(by: -.pi / 2)
//        default:
//            break
//        }
//        
//        switch imageOrientation {
//        case .upMirrored, .downMirrored:
//            transform = transform.translatedBy(x: size.width, y: 0)
//            transform = transform.scaledBy(x: -1, y: 1)
//        case .leftMirrored, .rightMirrored:
//            transform = transform.translatedBy(x: size.height, y: 0)
//            transform = transform.scaledBy(x: -1, y: 1)
//        default:
//            break
//        }
//        
//        guard let cgImage = cgImage,
//              let colorSpace = cgImage.colorSpace,
//              let context = CGContext(data: nil,
//                                    width: Int(size.width),
//                                    height: Int(size.height),
//                                    bitsPerComponent: cgImage.bitsPerComponent,
//                                    bytesPerRow: 0,
//                                    space: colorSpace,
//                                    bitmapInfo: cgImage.bitmapInfo.rawValue) else {
//            return self
//        }
//        
//        context.concatenate(transform)
//        
//        switch imageOrientation {
//        case .left, .leftMirrored, .right, .rightMirrored:
//            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
//        default:
//            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//        }
//        
//        guard let newCGImage = context.makeImage() else { return self }
//        return UIImage(cgImage: newCGImage)
//    }
//    
//    func resized(toWidth width: CGFloat) -> UIImage? {
//        let scale = width / size.width
//        let newHeight = size.height * scale
//        let newSize = CGSize(width: width, height: newHeight)
//        
//        let format = UIGraphicsImageRendererFormat()
//        format.scale = 1.0
//        format.opaque = true
//        
//        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
//        return renderer.image { _ in
//            draw(in: CGRect(origin: .zero, size: newSize))
//        }
//    }
//}









import ARKit
import UIKit

/**
 * CameraStreamManager handles real-time camera frame capture and streaming
 * with adaptive quality based on network conditions.
 *
 * This class captures frames from an ARKit camera session, processes them,
 * and sends them over a network connection with automatic quality adjustment.
 */
class CameraStreamManager: NSObject, ObservableObject {
    // MARK: - Timer and Frame Rate Properties
    private var frameTimer: Timer?                    // Timer that triggers frame capture at regular intervals
    private let targetFPS: Double = 30.0             // Desired frames per second for streaming
    private var lastFrameTime: TimeInterval = 0      // Timestamp of the last captured frame
    
    // MARK: - Published Properties (Observable by SwiftUI)
    @Published var isStreaming = false               // Current streaming status - observable by UI
    
    // MARK: - Image Quality and Compression Settings
    private let baseJpegQuality: CGFloat = 0.7       // Default JPEG compression quality (0.0 = max compression, 1.0 = no compression)
    private let maxImageWidth: CGFloat = 854         // Maximum width for processed images in pixels
    private let maxChunkSize = 65536                 // Maximum size for data chunks when sending large images (64KB)
    private let adaptiveQualityEnabled = true        // Flag to enable/disable automatic quality adjustment
    private var currentQuality: CGFloat = 0.7        // Current JPEG quality being used
    
    // MARK: - Network Adaptation Properties
    private var networkCondition: NetworkCondition = .good  // Current assessed network quality
    private var frameSkipCounter = 0                 // Counter to track frames for selective skipping
    private var sendTimes: [TimeInterval] = []       // Array storing recent frame processing times for performance analysis
    
    /**
     * Enum representing different network conditions and their associated parameters
     * Each condition has different limits for file size and target quality
     */
    enum NetworkCondition {
        case excellent, good, fair, poor
        
        /// Maximum allowed file size for each network condition
        var maxSize: Int {
            switch self {
            case .excellent: return 131072    // 128KB - high quality networks
            case .good: return 65536         // 64KB - standard networks
            case .fair: return 32768         // 32KB - slower networks
            case .poor: return 16384         // 16KB - very slow networks
            }
        }
        
        /// Target JPEG compression quality for each network condition
        var targetQuality: CGFloat {
            switch self {
            case .excellent: return 0.8      // High quality for fast networks
            case .good: return 0.7          // Standard quality
            case .fair: return 0.5          // Reduced quality for slower networks
            case .poor: return 0.3          // Low quality for very slow networks
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /**
     * Starts the camera streaming process
     * - Parameter sceneView: The ARSCNView that provides the camera feed
     */
    func startStreaming(from sceneView: ARSCNView) {
        // Update streaming status on main thread (required for @Published property)
        DispatchQueue.main.async {
            self.isStreaming = true
        }
        
        // Set up timer on main thread to capture frames at target FPS
        DispatchQueue.main.async {
            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.targetFPS, repeats: true) { [weak self] _ in
                self?.captureAndSendFrame(from: sceneView)
            }
        }
    }
    
    /**
     * Stops the camera streaming process and cleans up resources
     */
    func stopStreaming() {
        DispatchQueue.main.async {
            self.isStreaming = false           // Update streaming status
            self.frameTimer?.invalidate()      // Stop the timer
            self.frameTimer = nil              // Release timer reference
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Captures a frame from the AR camera and processes it for transmission
     * This method handles frame rate limiting, quality adaptation, and image processing
     * - Parameter sceneView: The ARSCNView providing the camera feed
     */
    private func captureAndSendFrame(from sceneView: ARSCNView) {
        // Get the current camera frame from ARKit session
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        // Frame rate limiting: ensure we don't process frames faster than target FPS
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFrameTime < (1.0 / targetFPS) {
            return  // Skip this frame if not enough time has passed
        }
        lastFrameTime = currentTime
        
        // Adapt network quality based on recent performance if enabled
        if adaptiveQualityEnabled {
            adaptNetworkQuality()
        }
        
        // Determine if we should skip this frame based on network conditions
        let shouldSkipFrame = frameSkipCounter % getFrameSkipRatio() != 0
        frameSkipCounter += 1
        
        // Skip frame if network is poor and frame skipping logic says to skip
        if shouldSkipFrame && networkCondition == .poor {
            return
        }
        
        // Process image on background thread to avoid blocking the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = CACurrentMediaTime()  // Start timing the processing
            
            // Convert ARKit's CVPixelBuffer to CIImage for processing
            let ciImage = CIImage(cvPixelBuffer: currentFrame.capturedImage)
            
            // Create a CIContext for image processing with performance optimizations
            let context = CIContext(options: [
                .useSoftwareRenderer: false,    // Use GPU acceleration when available
                .priorityRequestLow: false      // High priority processing
            ])
            
            // Convert CIImage to CGImage
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            // Handle device orientation to ensure proper image orientation
            let deviceOrientation = UIDevice.current.orientation
            let imageOrientation = self.getImageOrientation(deviceOrientation: deviceOrientation)
            var uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
            
            // Fix any orientation issues
            uiImage = uiImage.fixedOrientation()
            
            // Resize image based on current network conditions
            let targetWidth = self.getAdaptiveImageWidth()
            if let resizedImage = uiImage.resized(toWidth: targetWidth) {
                var imageData: Data?
                var quality = self.currentQuality
                let maxAllowedSize = self.networkCondition.maxSize
                
                // Compress image iteratively until it fits within size limits
                repeat {
                    imageData = resizedImage.jpegData(compressionQuality: quality)
                    if let data = imageData, data.count <= maxAllowedSize {
                        break  // Image is small enough
                    }
                    quality -= 0.05  // Reduce quality and try again
                } while quality > 0.15  // Don't go below minimum quality
                
                // Send the processed image data
                if let finalImageData = imageData {
                    let processTime = CACurrentMediaTime() - startTime
                    self.recordSendTime(processTime)  // Record processing time for network adaptation
                    
                    // Send as single message if small enough, otherwise chunk it
                    if finalImageData.count <= 32768 {
                        SocketManager.shared.sendImageData(finalImageData)
                    } else {
                        self.sendChunkedData(finalImageData, type: "IMAGE")
                    }
                }
            }
        }
    }
    
    /**
     * Returns the appropriate image width based on current network conditions
     * Better networks can handle higher resolution images
     */
    private func getAdaptiveImageWidth() -> CGFloat {
        switch networkCondition {
        case .excellent: return 1080     // Full HD width for excellent networks
        case .good: return 854          // Standard streaming resolution
        case .fair: return 640          // Reduced resolution for fair networks
        case .poor: return 480          // Low resolution for poor networks
        }
    }
    
    /**
     * Returns how many frames to skip based on network conditions
     * Poor networks skip more frames to reduce bandwidth usage
     */
    private func getFrameSkipRatio() -> Int {
        switch networkCondition {
        case .excellent: return 1        // Send every frame
        case .good: return 1            // Send every frame
        case .fair: return 2            // Send every 2nd frame (15 FPS effective)
        case .poor: return 3            // Send every 3rd frame (10 FPS effective)
        }
    }
    
    /**
     * Records processing time for network quality assessment
     * Keeps a rolling window of recent processing times
     * - Parameter time: The time taken to process the current frame
     */
    private func recordSendTime(_ time: TimeInterval) {
        sendTimes.append(time)
        if sendTimes.count > 10 {
            sendTimes.removeFirst()  // Keep only the most recent 10 times
        }
    }
    
    /**
     * Analyzes recent processing times to determine network condition
     * and adjusts streaming parameters accordingly
     */
    private func adaptNetworkQuality() {
        guard sendTimes.count >= 5 else { return }  // Need sufficient data points
        
        // Calculate average processing time
        let avgTime = sendTimes.reduce(0, +) / Double(sendTimes.count)
        
        // Classify network condition based on average processing time
        switch avgTime {
        case 0..<0.03:           // Very fast processing (< 30ms)
            networkCondition = .excellent
        case 0.03..<0.06:        // Fast processing (30-60ms)
            networkCondition = .good
        case 0.06..<0.12:        // Moderate processing (60-120ms)
            networkCondition = .fair
        default:                 // Slow processing (> 120ms)
            networkCondition = .poor
        }
        
        // Update quality setting based on detected network condition
        currentQuality = networkCondition.targetQuality
    }
    
    /**
     * Sends large data by breaking it into smaller chunks
     * This prevents network timeouts and allows for better error handling
     * - Parameter data: The data to be sent
     * - Parameter type: The type of data being sent (e.g., "IMAGE")
     */
    private func sendChunkedData(_ data: Data, type: String) {
        let chunkId = UUID().uuidString  // Unique identifier for this set of chunks
        let totalChunks = (data.count + maxChunkSize - 1) / maxChunkSize  // Calculate total chunks needed
        
        // Send each chunk with metadata
        for i in 0..<totalChunks {
            let startIndex = i * maxChunkSize
            let endIndex = min(startIndex + maxChunkSize, data.count)
            let chunk = data.subdata(in: startIndex..<endIndex)
            
            // Create chunk message with metadata for reassembly
            let chunkMessage: [String: Any] = [
                "type": "CHUNK",                           // Message type
                "dataType": type,                          // Original data type
                "chunkId": chunkId,                       // Unique ID for this chunked data
                "chunkIndex": i,                          // Index of this chunk
                "totalChunks": totalChunks,               // Total number of chunks
                "data": chunk.base64EncodedString()       // Base64 encoded chunk data
            ]
            
            // Convert to JSON and send
            if let jsonData = try? JSONSerialization.data(withJSONObject: chunkMessage) {
                SocketManager.shared.sendRawData(jsonData)
            }
        }
    }
    
    /**
     * Determines the correct UIImage orientation based on device orientation
     * This ensures images appear correctly oriented regardless of how the device is held
     * - Parameter deviceOrientation: Current device orientation
     * - Returns: Appropriate UIImage.Orientation
     */
    private func getImageOrientation(deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:             // Device held normally
            return .right
        case .portraitUpsideDown:   // Device upside down
            return .left
        case .landscapeLeft:        // Device rotated left
            return .up
        case .landscapeRight:       // Device rotated right
            return .down
        default:                    // Unknown or face up/down
            return .right
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    /**
     * Fixes image orientation by applying appropriate transformations
     * This ensures the image displays correctly regardless of how it was captured
     * - Returns: UIImage with corrected orientation
     */
    func fixedOrientation() -> UIImage {
        // If orientation is already correct, return as-is
        guard imageOrientation != .up else { return self }
        
        var transform = CGAffineTransform.identity
        
        // Apply rotation transformations based on current orientation
        switch imageOrientation {
        case .down, .downMirrored:      // Image is upside down
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)  // Rotate 180 degrees
        case .left, .leftMirrored:      // Image is rotated left
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)  // Rotate 90 degrees clockwise
        case .right, .rightMirrored:    // Image is rotated right
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)  // Rotate 90 degrees counter-clockwise
        default:
            break
        }
        
        // Apply mirroring transformations if needed
        switch imageOrientation {
        case .upMirrored, .downMirrored:    // Horizontally mirrored
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)  // Flip horizontally
        case .leftMirrored, .rightMirrored: // Vertically mirrored
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)  // Flip horizontally
        default:
            break
        }
        
        // Create graphics context and apply transformations
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
        
        context.concatenate(transform)  // Apply the transformation
        
        // Draw the image with appropriate dimensions based on orientation
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            // For rotated images, swap width and height
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            // For non-rotated images, use original dimensions
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        // Create new UIImage from the transformed context
        guard let newCGImage = context.makeImage() else { return self }
        return UIImage(cgImage: newCGImage)
    }
    
    /**
     * Resizes the image to a specific width while maintaining aspect ratio
     * Uses high-quality rendering for optimal results
     * - Parameter width: Target width in points
     * - Returns: Resized UIImage, or nil if resizing fails
     */
    func resized(toWidth width: CGFloat) -> UIImage? {
        let scale = width / size.width           // Calculate scale factor
        let newHeight = size.height * scale      // Calculate new height maintaining aspect ratio
        let newSize = CGSize(width: width, height: newHeight)
        
        // Configure rendering format for optimal quality
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0      // Use point-for-point rendering
        format.opaque = true    // Optimize for opaque images (no transparency)
        
        // Create renderer and generate resized image
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
