
import SwiftUI
import ARKit

struct UserARView: View {
    @StateObject private var socketManager = SocketManager.shared
    @StateObject private var streamManager = CameraStreamManager()
    @StateObject private var drawingManager = DrawingManager()
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var audioSocketHandler = AudioSocketHandler.shared
    @StateObject private var arFeedbackManager = ARFeedbackManager()
    @Environment(\.dismiss) private var dismiss
    
    @State private var arView: ARSCNView?
    
    var body: some View {
        ZStack {
            ARViewContainer(
                streamManager: streamManager,
                drawingManager: drawingManager,
                arFeedbackManager: arFeedbackManager,
                arView: $arView
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if streamManager.isStreaming {
                            Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        
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
                .padding(.top, 50)
                
                Spacer()
                
                VStack(spacing: 20) {
                    if audioManager.isCallActive {
                        VStack(spacing: 12) {
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
                            
                            HStack(spacing: 16) {
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
                    
                    if !socketManager.isConnected {
                        Button(action: {
                            socketManager.connect(as: "user")
                            setupDrawingReceiver()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                audioSocketHandler.startAudioCall()
                            }
                        }) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.blue))
                        }
                    } else if !streamManager.isStreaming {
                        Button(action: {
                            streamManager.isStreaming = true
                        }) {
                            Image(systemName: "video")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.green))
                        }
                    } else {
                        Button(action: {
                            streamManager.stopStreaming()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(Color.red))
                        }
                    }
                    
                    Text(socketManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if socketManager.isConnected {
                setupDrawingReceiver()
                audioSocketHandler.startAudioCall()
            }
        }
        .onDisappear {
            disconnect()
        }
    }
    
    private func setupDrawingReceiver() {
        socketManager.onDrawingReceived = { [weak drawingManager, weak arFeedbackManager, weak arView] message in
            guard let drawingManager = drawingManager else { return }
            
            DispatchQueue.main.async {
                switch message.action {
                case .add:
                    if let stroke = message.stroke {
                        drawingManager.processIncomingStroke(stroke)
                        if let arView = arView, !arFeedbackManager!.isFeedbackActive {
                            arFeedbackManager!.startFeedback(from: arView)
                        }
                    }
                    
                case .update:
                    if let stroke = message.stroke {
                        drawingManager.processIncomingStroke(stroke)
                    }
                    
                case .remove:
                    drawingManager.removeDrawing(withId: message.drawingId)
                    
                case .render3D:
                    break
                }
            }
        }
        
        socketManager.onClearDrawings = { [weak drawingManager] in
            DispatchQueue.main.async {
                drawingManager?.clearAllDrawings()
            }
        }
    }
    
    private func disconnect() {
        arFeedbackManager.stopFeedback()
        audioSocketHandler.endAudioCall()
        streamManager.stopStreaming()
        socketManager.disconnect()
        drawingManager.clearAllDrawings()
        dismiss()
    }
}

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var streamManager: CameraStreamManager
    @ObservedObject var drawingManager: DrawingManager
    @ObservedObject var arFeedbackManager: ARFeedbackManager
    @Binding var arView: ARSCNView?
    
    func makeUIView(context: Context) -> ARSCNView {
        let arSceneView = ARSCNView()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isLightEstimationEnabled = true
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        
        arSceneView.session.run(configuration)
        
        arSceneView.autoenablesDefaultLighting = true
        arSceneView.automaticallyUpdatesLighting = true
        arSceneView.scene.lightingEnvironment.intensity = 1.0
        
        arSceneView.rendersContinuously = true
        arSceneView.preferredFramesPerSecond = 60
        arSceneView.contentScaleFactor = UIScreen.main.nativeScale
        
        arSceneView.contentMode = .scaleAspectFill
        arSceneView.clipsToBounds = true
        
        drawingManager.configure(with: arSceneView)
        
        arSceneView.delegate = context.coordinator
        
        DispatchQueue.main.async {
            self.arView = arSceneView
        }
        
        return arSceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(streamManager: streamManager, drawingManager: drawingManager)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        let streamManager: CameraStreamManager
        let drawingManager: DrawingManager
        private var hasStartedStreaming = false
        
        init(streamManager: CameraStreamManager, drawingManager: DrawingManager) {
            self.streamManager = streamManager
            self.drawingManager = drawingManager
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if streamManager.isStreaming && !hasStartedStreaming,
               let arView = renderer as? ARSCNView {
                hasStartedStreaming = true
                streamManager.startStreaming(from: arView)
            } else if !streamManager.isStreaming {
                hasStartedStreaming = false
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                    height: CGFloat(planeAnchor.extent.z))
                plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.05)
                plane.firstMaterial?.isDoubleSided = true
                
                let planeNode = SCNNode(geometry: plane)
                planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
                planeNode.eulerAngles.x = -.pi / 2
                
                node.addChildNode(planeNode)
            }
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor,
                  let planeNode = node.childNodes.first,
                  let plane = planeNode.geometry as? SCNPlane else { return }
            
            plane.width = CGFloat(planeAnchor.extent.x)
            plane.height = CGFloat(planeAnchor.extent.z)
            planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        }
    }
}

class ARFeedbackManager: ObservableObject {
    @Published var isFeedbackActive = false
    private var feedbackTimer: Timer?
    private let feedbackFPS: Double = 15.0
    private var lastFeedbackTime: TimeInterval = 0
    
    func startFeedback(from arView: ARSCNView) {
        guard !isFeedbackActive else { return }
        
        DispatchQueue.main.async {
            self.isFeedbackActive = true
            self.feedbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / self.feedbackFPS, repeats: true) { [weak self] _ in
                self?.captureFeedback(from: arView)
            }
        }
    }
    
    func stopFeedback() {
        DispatchQueue.main.async {
            self.isFeedbackActive = false
            self.feedbackTimer?.invalidate()
            self.feedbackTimer = nil
        }
    }
    
    private func captureFeedback(from arView: ARSCNView) {
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFeedbackTime < (1.0 / feedbackFPS) {
            return
        }
        lastFeedbackTime = currentTime
        
        DispatchQueue.main.async {
            let renderer = UIGraphicsImageRenderer(size: arView.bounds.size)
            let image = renderer.image { context in
                arView.drawHierarchy(in: arView.bounds, afterScreenUpdates: false)
            }
            
            if let resizedImage = image.resized(toWidth: 640),
               let imageData = resizedImage.jpegData(compressionQuality: 0.4) {
                
                var feedbackData = Data()
                feedbackData.append(contentsOf: "FEEDBACK:".utf8)
                feedbackData.append(imageData)
                
                SocketManager.shared.sendFeedbackData(feedbackData)
            }
        }
    }
}
