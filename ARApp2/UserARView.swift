
import SwiftUI
import ARKit

struct UserARView: View {
    @StateObject private var socketManager = SocketManager.shared
    @StateObject private var streamManager = CameraStreamManager()
    @StateObject private var drawingManager = DrawingManager()
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var audioSocketHandler = AudioSocketHandler.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            ARViewContainer(streamManager: streamManager, drawingManager: drawingManager)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: {
                        disconnect()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(socketManager.connectionStatus)
                            .font(.caption)
                        if streamManager.isStreaming {
                            Label("Streaming", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if audioManager.isCallActive {
                            Label("Call Active", systemImage: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 16) {
                    if audioManager.isCallActive {
                        CallControlsView()
                    }
                    
                    HStack {
                        if !socketManager.isConnected {
                            Button("Connect") {
                                socketManager.connect(as: "user")
                                setupDrawingReceiver()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    audioSocketHandler.startAudioCall()
                                }
                            }
                            .buttonStyle(StreamButtonStyle())
                        } else if !streamManager.isStreaming {
                            Button("Start Streaming") {
                                streamManager.isStreaming = true
                            }
                            .buttonStyle(StreamButtonStyle(color: .green))
                        } else {
                            Button("Stop Streaming") {
                                streamManager.stopStreaming()
                            }
                            .buttonStyle(StreamButtonStyle(color: .red))
                        }
                    }
                }
                .padding()
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
        socketManager.onDrawingReceived = { [weak drawingManager] message in
            guard let drawingManager = drawingManager else { return }
            
            switch message.action {
            case .add:
                if let stroke = message.stroke, !stroke.points.isEmpty {
                    let centerX = stroke.points.map { $0.x }.reduce(0, +) / Float(stroke.points.count)
                    let centerY = stroke.points.map { $0.y }.reduce(0, +) / Float(stroke.points.count)
                    let centerPoint = CGPoint(x: CGFloat(centerX), y: CGFloat(centerY))
                    
                    if let anchor = drawingManager.createDrawing3D(from: stroke, at: centerPoint) {
                        drawingManager.addDrawing(anchor)
                    }
                }
                
            case .update:
                if let stroke = message.stroke, !stroke.points.isEmpty {
                    let centerX = stroke.points.map { $0.x }.reduce(0, +) / Float(stroke.points.count)
                    let centerY = stroke.points.map { $0.y }.reduce(0, +) / Float(stroke.points.count)
                    let centerPoint = CGPoint(x: CGFloat(centerX), y: CGFloat(centerY))
                    
                    if let anchor = drawingManager.createDrawing3D(from: stroke, at: centerPoint) {
                        drawingManager.updateDrawing(anchor)
                    }
                }
                
            case .remove:
                drawingManager.removeDrawing(withId: message.drawingId)
            }
        }
        
        socketManager.onClearDrawings = { [weak drawingManager] in
            drawingManager?.clearAllDrawings()
        }
    }
    
    private func disconnect() {
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
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration)
        
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        
        drawingManager.configure(with: arView)
        
        arView.delegate = context.coordinator
        
        return arView
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
            guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
            
            let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                height: CGFloat(planeAnchor.extent.z))
            plane.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
            
            let planeNode = SCNNode(geometry: plane)
            planeNode.simdPosition = simd_float3(planeAnchor.center.x, 0, planeAnchor.center.z)
            planeNode.eulerAngles.x = -.pi / 2
            
            node.addChildNode(planeNode)
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

struct StreamButtonStyle: ButtonStyle {
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}













