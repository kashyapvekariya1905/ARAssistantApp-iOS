//import SwiftUI
//import ARKit
//
//struct UserARView: View {
//    @StateObject private var socketManager = SocketManager.shared
//    @StateObject private var streamManager = CameraStreamManager()
//    @StateObject private var drawingManager = DrawingManager()
//    @StateObject private var audioManager = AudioManager.shared
//    @StateObject private var audioSocketHandler = AudioSocketHandler.shared
//    @StateObject private var arFeedbackManager = ARFeedbackManager()
//    @Environment(\.dismiss) private var dismiss
//    
//    @State private var arView: ARSCNView?
//    
//    var body: some View {
//        ZStack {
//            ARViewContainer(
//                streamManager: streamManager,
//                drawingManager: drawingManager,
//                arFeedbackManager: arFeedbackManager,
//                arView: $arView
//            )
//            .edgesIgnoringSafeArea(.all)
//            
//            VStack {
//                HStack {
//                    Button(action: {
//                        disconnect()
//                    }) {
//                        Image(systemName: "chevron.left")
//                            .font(.system(size: 24))
//                            .foregroundColor(.white)
//                            .padding()
//                            .background(Circle().fill(Color.black.opacity(0.3)))
//                    }
//                    .padding(.leading)
//                    
//                    Spacer()
//                    
//                    VStack(alignment: .trailing, spacing: 4) {
//                        if streamManager.isStreaming {
//                            Label("Live", systemImage: "dot.radiowaves.left.and.right")
//                                .font(.caption)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 6)
//                                .background(Color.red)
//                                .cornerRadius(4)
//                        }
//                        
//                        if arFeedbackManager.isFeedbackActive {
//                            Label("AR Active", systemImage: "viewfinder")
//                                .font(.caption2)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 8)
//                                .padding(.vertical, 4)
//                                .background(Color.purple.opacity(0.8))
//                                .cornerRadius(4)
//                        }
//                    }
//                    .padding(.trailing)
//                }
//                .padding(.top, 50)
//                
//                Spacer()
//                
//                VStack(spacing: 20) {
//                    if audioManager.isCallActive {
//                        VStack(spacing: 12) {
//                            HStack {
//                                Image(systemName: audioManager.isCallOnHold ? "pause.circle.fill" : "phone.fill")
//                                    .foregroundColor(audioManager.isCallOnHold ? .orange : .green)
//                                Text(audioManager.isCallOnHold ? "Call On Hold" : "Call Active")
//                                    .foregroundColor(.white)
//                            }
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 8)
//                            .background(Color.black.opacity(0.6))
//                            .cornerRadius(20)
//                            
//                            HStack(spacing: 16) {
//                                Button(action: {
//                                    audioManager.toggleMic()
//                                }) {
//                                    VStack {
//                                        Image(systemName: audioManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
//                                            .font(.system(size: 20))
//                                        Text(audioManager.isMicMuted ? "Unmute" : "Mute")
//                                            .font(.system(size: 10))
//                                    }
//                                    .frame(width: 50, height: 50)
//                                    .foregroundColor(.white)
//                                    .background(audioManager.isMicMuted ? Color.red : Color.gray.opacity(0.6))
//                                    .clipShape(Circle())
//                                }
//                                
//                                Button(action: {
//                                    audioManager.toggleHold()
//                                }) {
//                                    VStack {
//                                        Image(systemName: audioManager.isCallOnHold ? "play.fill" : "pause.fill")
//                                            .font(.system(size: 20))
//                                        Text(audioManager.isCallOnHold ? "Resume" : "Hold")
//                                            .font(.system(size: 10))
//                                    }
//                                    .frame(width: 50, height: 50)
//                                    .foregroundColor(.white)
//                                    .background(audioManager.isCallOnHold ? Color.orange : Color.gray.opacity(0.6))
//                                    .clipShape(Circle())
//                                }
//                                
//                                Button(action: {
//                                    audioSocketHandler.endAudioCall()
//                                }) {
//                                    VStack {
//                                        Image(systemName: "phone.down.fill")
//                                            .font(.system(size: 20))
//                                        Text("End")
//                                            .font(.system(size: 10))
//                                    }
//                                    .frame(width: 50, height: 50)
//                                    .foregroundColor(.white)
//                                    .background(Color.red)
//                                    .clipShape(Circle())
//                                }
//                                
//                                Button(action: {
//                                    audioManager.toggleSpeaker()
//                                }) {
//                                    VStack {
//                                        Image(systemName: audioManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
//                                            .font(.system(size: 20))
//                                        Text("Speaker")
//                                            .font(.system(size: 10))
//                                    }
//                                    .frame(width: 50, height: 50)
//                                    .foregroundColor(.white)
//                                    .background(audioManager.isSpeakerOn ? Color.blue : Color.gray.opacity(0.6))
//                                    .clipShape(Circle())
//                                }
//                            }
//                            .padding(.horizontal, 16)
//                            .padding(.vertical, 8)
//                            .background(Color.black.opacity(0.6))
//                            .cornerRadius(15)
//                        }
//                    }
//                    
//                    if !socketManager.isConnected {
//                        VStack(spacing: 8) {
//                            Button(action: {
//                                socketManager.connect(as: "user")
//                                setupDrawingReceiver()
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                    audioSocketHandler.startAudioCall()
//                                }
//                            }) {
//                                Image(systemName: "antenna.radiowaves.left.and.right")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(.white)
//                                    .frame(width: 70, height: 70)
//                                    .background(Circle().fill(Color.blue))
//                            }
//                            Text("Connect to Server")
//                                .font(.caption)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 4)
//                                .background(Color.black.opacity(0.6))
//                                .cornerRadius(8)
//                        }
//                    } else if !streamManager.isStreaming {
//                        VStack(spacing: 8) {
//                            Button(action: {
//                                streamManager.isStreaming = true
//                            }) {
//                                Image(systemName: "video")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(.white)
//                                    .frame(width: 70, height: 70)
//                                    .background(Circle().fill(Color.green))
//                            }
//                            Text("Start Camera Stream")
//                                .font(.caption)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 4)
//                                .background(Color.black.opacity(0.6))
//                                .cornerRadius(8)
//                        }
//                    } else {
//                        VStack(spacing: 8) {
//                            Button(action: {
//                                streamManager.stopStreaming()
//                            }) {
//                                Image(systemName: "stop.fill")
//                                    .font(.system(size: 30))
//                                    .foregroundColor(.white)
//                                    .frame(width: 70, height: 70)
//                                    .background(Circle().fill(Color.red))
//                            }
//                            Text("Stop Streaming")
//                                .font(.caption)
//                                .foregroundColor(.white)
//                                .padding(.horizontal, 12)
//                                .padding(.vertical, 4)
//                                .background(Color.black.opacity(0.6))
//                                .cornerRadius(8)
//                        }
//                    }
//                    
//                    Text(socketManager.connectionStatus)
//                        .font(.caption)
//                        .foregroundColor(.white)
//                        .padding(.horizontal, 12)
//                        .padding(.vertical, 6)
//                        .background(Color.black.opacity(0.6))
//                        .cornerRadius(12)
//                }
//                .padding(.bottom, 40)
//            }
//        }
//        .navigationBarHidden(true)
//        .onAppear {
//            if socketManager.isConnected {
//                setupDrawingReceiver()
//                audioSocketHandler.startAudioCall()
//            }
//        }
//        .onDisappear {
//            disconnect()
//        }
//    }
//    
//    private func setupDrawingReceiver() {
//        socketManager.onDrawingReceived = { [weak drawingManager, weak arFeedbackManager, weak arView] message in
//            guard let drawingManager = drawingManager else { return }
//            
//            DispatchQueue.main.async {
//                switch message.action {
//                case .add:
//                    if let stroke = message.stroke {
//                        drawingManager.processIncomingStroke(stroke)
//                        if let arView = arView, !arFeedbackManager!.isFeedbackActive {
//                            arFeedbackManager!.startFeedback(from: arView)
//                        }
//                    }
//                    
//                case .update:
//                    if let stroke = message.stroke {
//                        drawingManager.processIncomingStroke(stroke)
//                    }
//                    
//                case .remove:
//                    drawingManager.removeDrawing(withId: message.drawingId)
//                    
//                case .render3D:
//                    break
//                }
//            }
//        }
//        
//        socketManager.onClearDrawings = { [weak drawingManager] in
//            DispatchQueue.main.async {
//                drawingManager?.clearAllDrawings()
//            }
//        }
//    }
//    
//    private func disconnect() {
//        arFeedbackManager.stopFeedback()
//        audioSocketHandler.endAudioCall()
//        streamManager.stopStreaming()
//        socketManager.disconnect()
//        drawingManager.clearAllDrawings()
//        dismiss()
//    }
//}
//
//struct ARViewContainer: UIViewRepresentable {
//    @ObservedObject var streamManager: CameraStreamManager
//    @ObservedObject var drawingManager: DrawingManager
//    @ObservedObject var arFeedbackManager: ARFeedbackManager
//    @Binding var arView: ARSCNView?
//    
//    func makeUIView(context: Context) -> ARSCNView {
//        let arSceneView = ARSCNView()
//        
//        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.horizontal, .vertical]
//        configuration.isLightEstimationEnabled = true
//        configuration.worldAlignment = .gravity
//        configuration.isAutoFocusEnabled = true
//        
//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
//            configuration.sceneReconstruction = .mesh
//        }
//        
//        arSceneView.session.run(configuration)
//        
//        arSceneView.autoenablesDefaultLighting = true
//        arSceneView.automaticallyUpdatesLighting = true
//        arSceneView.scene.lightingEnvironment.intensity = 1.0
//        
//        arSceneView.rendersContinuously = true
//        arSceneView.preferredFramesPerSecond = 60
//        arSceneView.contentScaleFactor = UIScreen.main.nativeScale
//        
//        arSceneView.contentMode = .scaleAspectFill
//        arSceneView.clipsToBounds = true
//        
//        drawingManager.configure(with: arSceneView)
//        
//        arSceneView.delegate = context.coordinator
//        
//        DispatchQueue.main.async {
//            self.arView = arSceneView
//        }
//        
//        return arSceneView
//    }
//    
//    func updateUIView(_ uiView: ARSCNView, context: Context) {
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(streamManager: streamManager, drawingManager: drawingManager)
//    }
//    
//    class Coordinator: NSObject, ARSCNViewDelegate {
//        let streamManager: CameraStreamManager
//        let drawingManager: DrawingManager
//        private var hasStartedStreaming = false
//        
//        init(streamManager: CameraStreamManager, drawingManager: DrawingManager) {
//            self.streamManager = streamManager
//            self.drawingManager = drawingManager
//        }
//        
//        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
//            if streamManager.isStreaming && !hasStartedStreaming,
//               let arView = renderer as? ARSCNView {
//                hasStartedStreaming = true
//                streamManager.startStreaming(from: arView)
//            } else if !streamManager.isStreaming {
//                hasStartedStreaming = false
//            }
//        }
//        
//        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//            if let planeAnchor = anchor as? ARPlaneAnchor {
//                let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x),
//                                    height: CGFloat(planeAnchor.extent.z))
//                plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.05)
//                plane.firstMaterial?.isDoubleSided = true
//                
//                let planeNode = SCNNode(geometry: plane)
//                planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
//                planeNode.eulerAngles.x = -.pi / 2
//                
//                node.addChildNode(planeNode)
//            }
//        }
//        
//        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
//            guard let planeAnchor = anchor as? ARPlaneAnchor,
//                  let planeNode = node.childNodes.first,
//                  let plane = planeNode.geometry as? SCNPlane else { return }
//            
//            plane.width = CGFloat(planeAnchor.extent.x)
//            plane.height = CGFloat(planeAnchor.extent.z)
//            planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
//        }
//    }
//}
//
//class ARFeedbackManager: ObservableObject {
//    @Published var isFeedbackActive = false
//    private var feedbackTimer: Timer?
//    private let feedbackFPS: Double = 15.0
//    private var lastFeedbackTime: TimeInterval = 0
//    
//    func startFeedback(from arView: ARSCNView) {
//        guard !isFeedbackActive else { return }
//        
//        DispatchQueue.main.async {
//            self.isFeedbackActive = true
//            self.feedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.feedbackFPS, repeats: true) { [weak self] _ in
//                self?.captureFeedback(from: arView)
//            }
//        }
//    }
//    
//    func stopFeedback() {
//        DispatchQueue.main.async {
//            self.isFeedbackActive = false
//            self.feedbackTimer?.invalidate()
//            self.feedbackTimer = nil
//        }
//    }
//    
//    private func captureFeedback(from arView: ARSCNView) {
//        let currentTime = CACurrentMediaTime()
//        if currentTime - lastFeedbackTime < (1.0 / feedbackFPS) {
//            return
//        }
//        lastFeedbackTime = currentTime
//        
//        DispatchQueue.main.async {
//            let renderer = UIGraphicsImageRenderer(size: arView.bounds.size)
//            let image = renderer.image { context in
//                arView.drawHierarchy(in: arView.bounds, afterScreenUpdates: false)
//            }
//            
//            if let resizedImage = image.resized(toWidth: 640),
//               let imageData = resizedImage.jpegData(compressionQuality: 0.4) {
//                
//                var feedbackData = Data()
//                feedbackData.append(contentsOf: "FEEDBACK:".utf8)
//                feedbackData.append(imageData)
//                
//                SocketManager.shared.sendFeedbackData(feedbackData)
//            }
//        }
//    }
//}


















import SwiftUI
import ARKit

// MARK: - Main User AR View
/// Main SwiftUI view that provides AR functionality for users
/// Combines camera streaming, drawing capabilities, audio calling, and AR feedback
struct UserARView: View {
    // MARK: - State Objects
    /// Manager instances for different functionalities
    @StateObject private var socketManager = SocketManager.shared           // WebSocket communication
    @StateObject private var streamManager = CameraStreamManager()          // Camera streaming to server
    @StateObject private var drawingManager = DrawingManager()              // AR drawing management
    @StateObject private var audioManager = AudioManager.shared             // Audio call management
    @StateObject private var audioSocketHandler = AudioSocketHandler.shared // Audio data transmission
    @StateObject private var arFeedbackManager = ARFeedbackManager()       // AR feedback capture
    @Environment(\.dismiss) private var dismiss                              // SwiftUI dismiss environment
    
    // MARK: - State Variables
    @State private var arView: ARSCNView?  // Reference to the AR scene view for interaction
    
    var body: some View {
        ZStack {
            // MARK: - AR View Container
            /// Main AR view that handles camera, scene rendering, and drawing
            ARViewContainer(
                streamManager: streamManager,
                drawingManager: drawingManager,
                arFeedbackManager: arFeedbackManager,
                arView: $arView
            )
            .edgesIgnoringSafeArea(.all)  // Full screen AR experience
            
            // MARK: - UI Overlay
            VStack {
                // MARK: - Top Navigation Bar
                HStack {
                    // Back button to disconnect and return to previous screen
                    Button(action: {
                        disconnect()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.3)))
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    // Status indicators for streaming and AR feedback
                    VStack(alignment: .trailing, spacing: 4) {
                        // Live streaming indicator
                        if streamManager.isStreaming {
                            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        
                        // AR feedback active indicator
                        if arFeedbackManager.isFeedbackActive {
                            Label("AR Active", systemImage: "viewfinder")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.top, 50)  // Account for safe area
                
                Spacer()
                
                // MARK: - Bottom Control Panel
                VStack(spacing: 20) {
                    // MARK: - Audio Call Controls
                    /// Display call controls when audio call is active
                    if audioManager.isCallActive {
                        VStack(spacing: 12) {
                            // Call status indicator
                            HStack {
                                Image(systemName: audioManager.isCallOnHold ? "pause.circle.fill" : "phone.fill")
                                    .foregroundColor(audioManager.isCallOnHold ? .orange : .green)
                                Text(audioManager.isCallOnHold ? "Call On Hold" : "Call Active")
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(20)
                            
                            // Audio control buttons
                            HStack(spacing: 16) {
                                // Microphone mute/unmute button
                                Button(action: {
                                    audioManager.toggleMic()
                                }) {
                                    VStack {
                                        Image(systemName: audioManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
                                            .font(.system(size: 20))
                                        Text(audioManager.isMicMuted ? "Unmute" : "Mute")
                                            .font(.system(size: 10))
                                    }
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .background(audioManager.isMicMuted ? Color.red : Color.gray.opacity(0.6))
                                    .clipShape(Circle())
                                }
                                
                                // Call hold/resume button
                                Button(action: {
                                    audioManager.toggleHold()
                                }) {
                                    VStack {
                                        Image(systemName: audioManager.isCallOnHold ? "play.fill" : "pause.fill")
                                            .font(.system(size: 20))
                                        Text(audioManager.isCallOnHold ? "Resume" : "Hold")
                                            .font(.system(size: 10))
                                    }
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .background(audioManager.isCallOnHold ? Color.orange : Color.gray.opacity(0.6))
                                    .clipShape(Circle())
                                }
                                
                                // End call button
                                Button(action: {
                                    audioSocketHandler.endAudioCall()
                                }) {
                                    VStack {
                                        Image(systemName: "phone.down.fill")
                                            .font(.system(size: 20))
                                        Text("End")
                                            .font(.system(size: 10))
                                    }
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                }
                                
                                // Speaker on/off button
                                Button(action: {
                                    audioManager.toggleSpeaker()
                                }) {
                                    VStack {
                                        Image(systemName: audioManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                                            .font(.system(size: 20))
                                        Text("Speaker")
                                            .font(.system(size: 10))
                                    }
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .background(audioManager.isSpeakerOn ? Color.blue : Color.gray.opacity(0.6))
                                    .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                        }
                    }
                    
                    // MARK: - Connection and Streaming Controls
                    /// Show different buttons based on connection and streaming state
                    if !socketManager.isConnected {
                        // Connect to server button (shown when not connected)
                        VStack(spacing: 8) {
                            Button(action: {
                                socketManager.connect(as: "user")           // Connect as user role
                                setupDrawingReceiver()                     // Setup drawing message handlers
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    audioSocketHandler.startAudioCall()    // Start audio call after connection
                                }
                            }) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.blue))
                            }
                            Text("Connect to Server")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    } else if !streamManager.isStreaming {
                        // Start camera stream button (shown when connected but not streaming)
                        VStack(spacing: 8) {
                            Button(action: {
                                streamManager.isStreaming = true
                            }) {
                                Image(systemName: "video")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.green))
                            }
                            Text("Start Camera Stream")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    } else {
                        // Stop streaming button (shown when actively streaming)
                        VStack(spacing: 8) {
                            Button(action: {
                                streamManager.stopStreaming()
                            }) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.red))
                            }
                            Text("Stop Streaming")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Connection status display
                    Text(socketManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                }
                .padding(.bottom, 40)  // Account for safe area
            }
        }
        .navigationBarHidden(true)  // Hide default navigation bar for full AR experience
        .onAppear {
            // Setup connections if already connected (e.g., returning to view)
            if socketManager.isConnected {
                setupDrawingReceiver()
                audioSocketHandler.startAudioCall()
            }
        }
        .onDisappear {
            // Clean up when leaving the view
            disconnect()
        }
    }
    
    // MARK: - Drawing Message Setup
    /// Configures handlers for incoming drawing messages from other users
    private func setupDrawingReceiver() {
        // Handler for drawing-related messages (add, update, remove strokes)
        socketManager.onDrawingReceived = { [weak drawingManager, weak arFeedbackManager, weak arView] message in
            guard let drawingManager = drawingManager else { return }
            
            DispatchQueue.main.async {
                switch message.action {
                case .add:
                    // Add new drawing stroke and start AR feedback if needed
                    if let stroke = message.stroke {
                        drawingManager.processIncomingStroke(stroke)
                        // Start AR feedback when first drawing is received
                        if let arView = arView, !arFeedbackManager!.isFeedbackActive {
                            arFeedbackManager!.startFeedback(from: arView)
                        }
                    }
                    
                case .update:
                    // Update existing drawing stroke
                    if let stroke = message.stroke {
                        drawingManager.processIncomingStroke(stroke)
                    }
                    
                case .remove:
                    // Remove specific drawing
                    drawingManager.removeDrawing(withId: message.drawingId)
                    
                case .render3D:
                    // Handle 3D rendering command (currently not implemented)
                    break
                }
            }
        }
        
        // Handler for clear all drawings command
        socketManager.onClearDrawings = { [weak drawingManager] in
            DispatchQueue.main.async {
                drawingManager?.clearAllDrawings()
            }
        }
    }
    
    // MARK: - Cleanup and Disconnection
    /// Properly disconnects all services and cleans up resources
    private func disconnect() {
        arFeedbackManager.stopFeedback()    // Stop AR feedback capture
        audioSocketHandler.endAudioCall()  // End audio call
        streamManager.stopStreaming()      // Stop camera streaming
        socketManager.disconnect()          // Disconnect from server
        drawingManager.clearAllDrawings()   // Clear all drawings
        dismiss()                           // Dismiss the view
    }
}

// MARK: - AR View Container
/// UIViewRepresentable wrapper for ARSCNView to integrate with SwiftUI
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var streamManager: CameraStreamManager     // Camera streaming manager
    @ObservedObject var drawingManager: DrawingManager         // Drawing management
    @ObservedObject var arFeedbackManager: ARFeedbackManager  // AR feedback manager
    @Binding var arView: ARSCNView?                           // Binding to parent's AR view reference
    
    /// Creates the ARSCNView with proper AR configuration
    func makeUIView(context: Context) -> ARSCNView {
        let arSceneView = ARSCNView()
        
        // MARK: - AR Configuration Setup
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]  // Detect both plane types
        configuration.isLightEstimationEnabled = true           // Enable realistic lighting
        configuration.worldAlignment = .gravity                 // Align with gravity
        configuration.isAutoFocusEnabled = true                 // Enable auto focus
        
        // Enable scene mesh reconstruction if supported (for occlusion)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        // Start AR session with configuration
        arSceneView.session.run(configuration)
        
        // MARK: - Scene Rendering Setup
        arSceneView.autoenablesDefaultLighting = true          // Automatic lighting
        arSceneView.automaticallyUpdatesLighting = true        // Dynamic lighting updates
        arSceneView.scene.lightingEnvironment.intensity = 1.0  // Full lighting intensity
        
        // MARK: - Performance Configuration
        arSceneView.rendersContinuously = true                 // Continuous rendering for smooth experience
        arSceneView.preferredFramesPerSecond = 60              // High frame rate for smooth visuals
        arSceneView.contentScaleFactor = UIScreen.main.nativeScale  // Native resolution
        
        // MARK: - Display Configuration
        arSceneView.contentMode = .scaleAspectFill              // Fill screen maintaining aspect ratio
        arSceneView.clipsToBounds = true                        // Clip content to bounds
        
        // Configure drawing manager with this AR view
        drawingManager.configure(with: arSceneView)
        
        // Set delegate for AR events
        arSceneView.delegate = context.coordinator
        
        // Update parent's AR view reference
        DispatchQueue.main.async {
            self.arView = arSceneView
        }
        
        return arSceneView
    }
    
    /// Updates the AR view (currently no updates needed)
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No updates needed for this implementation
    }
    
    /// Creates coordinator to handle AR delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(streamManager: streamManager, drawingManager: drawingManager)
    }
    
    // MARK: - AR Scene Coordinator
    /// Handles AR scene delegate methods and manages streaming lifecycle
    class Coordinator: NSObject, ARSCNViewDelegate {
        let streamManager: CameraStreamManager    // Reference to stream manager
        let drawingManager: DrawingManager        // Reference to drawing manager
        private var hasStartedStreaming = false   // Flag to track streaming state
        
        init(streamManager: CameraStreamManager, drawingManager: DrawingManager) {
            self.streamManager = streamManager
            self.drawingManager = drawingManager
        }
        
        // MARK: - Scene Rendering Delegate
        /// Called after each frame is rendered - manages streaming lifecycle
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            // Start streaming when conditions are met
            if streamManager.isStreaming && !hasStartedStreaming,
               let arView = renderer as? ARSCNView {
                hasStartedStreaming = true
                streamManager.startStreaming(from: arView)
            } else if !streamManager.isStreaming {
                // Reset streaming flag when stopped
                hasStartedStreaming = false
            }
        }
        
        // MARK: - Plane Detection Delegate
        /// Called when a new AR anchor (plane) is detected
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Create visual representation for detected plane
                let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                    height: CGFloat(planeAnchor.extent.z))
                plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.05)  // Semi-transparent white
                plane.firstMaterial?.isDoubleSided = true  // Visible from both sides
                
                let planeNode = SCNNode(geometry: plane)
                planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
                planeNode.eulerAngles.x = -.pi / 2  // Rotate to lay flat
                
                node.addChildNode(planeNode)
            }
        }
        
        /// Called when an existing AR anchor (plane) is updated
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  let planeNode = node.childNodes.first,
                  let plane = planeNode.geometry as? SCNPlane else { return }
            
            // Update plane size and position as AR refines detection
            plane.width = CGFloat(planeAnchor.extent.x)
            plane.height = CGFloat(planeAnchor.extent.z)
            planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        }
    }
}

// MARK: - AR Feedback Manager
/// Manages capturing and sending AR feedback images to other connected devices
class ARFeedbackManager: ObservableObject {
    @Published var isFeedbackActive = false     // Whether feedback capture is currently active
    private var feedbackTimer: Timer?           // Timer for periodic feedback capture
    private let feedbackFPS: Double = 15.0      // Frame rate for feedback capture (15 FPS)
    private var lastFeedbackTime: TimeInterval = 0  // Track last capture time for throttling
    
    /// Starts periodic AR feedback capture from the provided AR view
    /// - Parameter arView: The ARSCNView to capture feedback from
    func startFeedback(from arView: ARSCNView) {
        guard !isFeedbackActive else { return }  // Don't start if already active
        
        DispatchQueue.main.async {
            self.isFeedbackActive = true
            // Create timer for periodic feedback capture
            self.feedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.feedbackFPS, repeats: true) { [weak self] _ in
                self?.captureFeedback(from: arView)
            }
        }
    }
    
    /// Stops AR feedback capture and cleans up resources
    func stopFeedback() {
        DispatchQueue.main.async {
            self.isFeedbackActive = false
            self.feedbackTimer?.invalidate()  // Stop the timer
            self.feedbackTimer = nil
        }
    }
    
    /// Captures a single feedback frame and sends it to connected devices
    /// - Parameter arView: The ARSCNView to capture from
    private func captureFeedback(from arView: ARSCNView) {
        let currentTime = CACurrentMediaTime()
        // Throttle capture to maintain consistent frame rate
        if currentTime - lastFeedbackTime < (1.0 / feedbackFPS) {
            return
        }
        lastFeedbackTime = currentTime
        
        DispatchQueue.main.async {
            // Create image renderer for the AR view's bounds
            let renderer = UIGraphicsImageRenderer(size: arView.bounds.size)
            let image = renderer.image { context in
                // Capture the current AR view content
                arView.drawHierarchy(in: arView.bounds, afterScreenUpdates: false)
            }
            
            // Resize and compress image for efficient transmission
            if let resizedImage = image.resized(toWidth: 640),  // Resize for bandwidth efficiency
               let imageData = resizedImage.jpegData(compressionQuality: 0.4) {  // Compress for faster transmission
                
                // Prepare feedback data with prefix for server identification
                var feedbackData = Data()
                feedbackData.append(contentsOf: "FEEDBACK:".utf8)  // Add prefix
                feedbackData.append(imageData)
                
                // Send feedback data through socket manager
                SocketManager.shared.sendFeedbackData(feedbackData)
            }
        }
    }
}
