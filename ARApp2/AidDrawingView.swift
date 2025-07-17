
import SwiftUI
import SceneKit

struct AidDrawingView: View {
    @StateObject private var socketManager = SocketManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var audioSocketHandler = AudioSocketHandler.shared
    @State private var currentImage: UIImage?
    @State private var frameCount = 0
    @State private var fps: Double = 0
    @State private var currentStroke: DrawingStroke?
    @State private var isDrawing = false
    @State private var drawingTool = DrawingTool()
    @State private var showToolbar = true
    @State private var completedStrokes: [DrawingStroke] = []
    @State private var show3DPreview = false
    @State private var showDepthGuide = false
    @Environment(\.dismiss) private var dismiss
    
    private let fpsTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack {
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("Waiting for stream...")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            if show3DPreview && (completedStrokes.count > 0 || (isDrawing && currentStroke != nil)) {
                ZStack {
                    Color.black.opacity(0.2)
                        .allowsHitTesting(false)
                    
                    GeometryReader { geometry in
                        Drawing3DPreviewView(
                            strokes: completedStrokes,
                            currentStroke: isDrawing ? currentStroke : nil,
                            viewSize: geometry.size,
                            backgroundImage: currentImage
                        )
                        .allowsHitTesting(false)
                    }
                }
            } else {
                DrawingPreviewView(strokes: completedStrokes)
                    .allowsHitTesting(false)
                
                if let stroke = currentStroke, isDrawing {
                    DrawingPreviewView(strokes: [stroke])
                        .allowsHitTesting(false)
                }
            }
            
            if showDepthGuide && currentImage != nil {
                DepthGuideOverlay()
                    .allowsHitTesting(false)
            }
            
            DrawingOverlay(
                currentStroke: $currentStroke,
                isDrawing: $isDrawing,
                tool: drawingTool,
                onStrokeCompleted: { stroke in
                    completedStrokes.append(stroke)
                    sendDrawing(stroke)
                }
            )
            .allowsHitTesting(currentImage != nil)
            
            VStack {
                HStack {
                    Button(action: disconnect) {
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
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(socketManager.connectionStatus)
                            .font(.caption)
                        if fps > 0 {
                            Text("\(Int(fps)) FPS")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        if audioManager.isCallActive {
                            Label("Call Active", systemImage: "phone.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: { show3DPreview.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: show3DPreview ? "cube.fill" : "square.fill")
                                        .font(.caption)
                                    Text(show3DPreview ? "3D" : "2D")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(show3DPreview ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            
                            Button(action: { showDepthGuide.toggle() }) {
                                Image(systemName: showDepthGuide ? "scope" : "scope")
                                    .font(.caption)
                                    .padding(6)
                                    .background(showDepthGuide ? Color.green : Color.gray)
                                    .foregroundColor(.white)
                                    .clipShape(Circle())
                            }
                        }
                        
                        if !showDepthGuide {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Tips:")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.yellow)
                                Text("• Larger brush = farther")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow.opacity(0.8))
                                Text("• Center = near")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow.opacity(0.8))
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
                
                if audioManager.isCallActive {
                    CallControlsView()
                        .padding(.bottom)
                }
                
                if showToolbar {
                    DrawingToolbar(
                        tool: $drawingTool,
                        onClear: clearDrawings,
                        onToggleToolbar: { showToolbar.toggle() }
                    )
                    .padding()
                }
            }
            
            if !showToolbar {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showToolbar.toggle() }) {
                            Image(systemName: "paintbrush.fill")
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupImageReceiver()
            if !socketManager.isConnected {
                socketManager.connect(as: "aid")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    audioSocketHandler.startAudioCall()
                }
            }
        }
        .onDisappear {
            disconnect()
        }
        .onReceive(fpsTimer) { _ in
            fps = Double(frameCount)
            frameCount = 0
        }
    }
    
    private func setupImageReceiver() {
        socketManager.onImageReceived = { [self] image in
            currentImage = image
            frameCount += 1
        }
        
        socketManager.onClearDrawings = { [self] in
            completedStrokes.removeAll()
        }
    }
    
    private func sendDrawing(_ stroke: DrawingStroke) {
        let message = DrawingMessage(
            action: .add,
            drawingId: stroke.id,
            stroke: stroke
        )
        socketManager.sendDrawingMessage(message)
    }
    
    private func clearDrawings() {
        completedStrokes.removeAll()
        socketManager.sendClearDrawings()
    }
    
    private func disconnect() {
        audioSocketHandler.endAudioCall()
        socketManager.disconnect()
        dismiss()
    }
}

struct DepthGuideOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                Text("Near")
                    .font(.caption2)
                    .foregroundColor(.green.opacity(0.5))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 60)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                    .padding(40)
                
                Text("Far")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.5))
                    .position(x: geometry.size.width - 60, y: 60)
                
                ForEach(0..<4) { i in
                    Path { path in
                        let progress = CGFloat(i) / 3.0
                        let inset = 40 + (geometry.size.width / 2 - 40) * progress
                        
                        path.move(to: CGPoint(x: inset, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: geometry.size.width - inset, y: geometry.size.height / 2))
                        
                        path.move(to: CGPoint(x: geometry.size.width / 2, y: inset))
                        path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height - inset))
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
            }
        }
    }
}

struct Drawing3DPreviewView: UIViewRepresentable {
    let strokes: [DrawingStroke]
    let currentStroke: DrawingStroke?
    let viewSize: CGSize
    let backgroundImage: UIImage?
    
    init(strokes: [DrawingStroke], currentStroke: DrawingStroke?, viewSize: CGSize, backgroundImage: UIImage? = nil) {
        self.strokes = strokes
        self.currentStroke = currentStroke
        self.viewSize = viewSize
        self.backgroundImage = backgroundImage
    }
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        cameraNode.camera?.usesOrthographicProjection = false
        cameraNode.camera?.fieldOfView = 60
        cameraNode.camera?.zNear = 0.001
        cameraNode.camera?.zFar = 1000
        
        cameraNode.position = SCNVector3(0, 0, 1)
        cameraNode.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1500
        lightNode.light?.color = UIColor.white
        lightNode.position = SCNVector3(0, 0, 2)
        sceneView.scene?.rootNode.addChildNode(lightNode)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        ambientLight.light?.color = UIColor(white: 0.9, alpha: 1.0)
        sceneView.scene?.rootNode.addChildNode(ambientLight)
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        sceneView.scene?.rootNode.childNodes
            .filter { $0.name == "stroke" }
            .forEach { $0.removeFromParentNode() }
        
        var allStrokes = strokes
        if let current = currentStroke {
            allStrokes.append(current)
        }
        
        for stroke in allStrokes {
            if let strokeNode = create3DStrokeWithPerspective(from: stroke, viewSize: viewSize) {
                strokeNode.name = "stroke"
                sceneView.scene?.rootNode.addChildNode(strokeNode)
            }
        }
    }
    
    private func create3DStrokeWithPerspective(from stroke: DrawingStroke, viewSize: CGSize) -> SCNNode? {
        guard stroke.points.count > 1 else { return nil }
        
        let strokeNode = SCNNode()
        
        let depth = estimateDepthFromDrawing(stroke: stroke)
        
        let points3D = stroke.points.map { point in
            let x = (point.x - 0.5) * 2.0
            let y = (0.5 - point.y) * 2.0 * Float(viewSize.height / viewSize.width)
            
            let perspectiveScale = depth
            
            return SCNVector3(
                x: x * perspectiveScale,
                y: y * perspectiveScale,
                z: -depth
            )
        }
        
        let baseThickness = stroke.thickness * (1.0 + depth * 0.5)
        
        for i in 0..<(points3D.count - 1) {
            let start = points3D[i]
            let end = points3D[i + 1]
            
            let segment = createPerspectiveTubeSegment(
                from: start,
                to: end,
                radius: CGFloat(baseThickness * 4.0),
                color: stroke.color.uiColor
            )
            
            strokeNode.addChildNode(segment)
        }
        
        for point in points3D {
            let sphere = SCNSphere(radius: CGFloat(baseThickness * 4.0))
            
            sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
            sphere.firstMaterial?.lightingModel = .phong
            sphere.firstMaterial?.specular.contents = UIColor.white
            sphere.firstMaterial?.shininess = 0.8
            sphere.firstMaterial?.emission.contents = stroke.color.uiColor
            sphere.firstMaterial?.emission.intensity = 0.3
            
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = point
            strokeNode.addChildNode(sphereNode)
        }
        
        return strokeNode
    }
    
    private func createPerspectiveTubeSegment(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
        let distance = simd_distance(
            simd_float3(start.x, start.y, start.z),
            simd_float3(end.x, end.y, end.z)
        )
        
        guard distance > 0 else { return SCNNode() }
        
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(distance))
        cylinder.radialSegmentCount = 12
        
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel = .phong
        cylinder.firstMaterial?.specular.contents = UIColor.white
        cylinder.firstMaterial?.shininess = 0.8
        cylinder.firstMaterial?.emission.contents = color
        cylinder.firstMaterial?.emission.intensity = 0.3
        
        let cylinderNode = SCNNode(geometry: cylinder)
        
        cylinderNode.position = SCNVector3(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2,
            z: (start.z + end.z) / 2
        )
        
        let direction = simd_normalize(
            simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
        )
        
        let up = simd_float3(0, 1, 0)
        let dot = simd_dot(up, direction)
        
        if abs(dot) > 0.999 {
            cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
        } else {
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(dot)
            cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        
        return cylinderNode
    }
    
    private func estimateDepthFromDrawing(stroke: DrawingStroke) -> Float {
        let minX = stroke.points.map { $0.x }.min() ?? 0
        let maxX = stroke.points.map { $0.x }.max() ?? 1
        let minY = stroke.points.map { $0.y }.min() ?? 0
        let maxY = stroke.points.map { $0.y }.max() ?? 1
        
        let width = maxX - minX
        let height = maxY - minY
        let size = max(width, height)
        
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let distanceFromCenter = hypot(centerX - 0.5, centerY - 0.5) * 2
        
        let sizeDepth = 1.0 - size
        let positionDepth = distanceFromCenter
        
        let depth = (sizeDepth * 0.7 + positionDepth * 0.3) * 2.0 + 0.5
        
        return depth
    }
}

struct DrawingPreviewView: View {
    let strokes: [DrawingStroke]
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(strokes, id: \.id) { stroke in
                Path { path in
                    guard stroke.points.count > 1 else { return }
                    
                    let points = stroke.points.map { point in
                        CGPoint(
                            x: CGFloat(point.x) * geometry.size.width,
                            y: CGFloat(point.y) * geometry.size.height
                        )
                    }
                    
                    path.move(to: points[0])
                    
                    for i in 1..<points.count {
                        path.addLine(to: points[i])
                    }
                }
                .stroke(Color(stroke.color.uiColor), lineWidth: CGFloat(stroke.thickness * 1200))
                .opacity(0.9)
                .shadow(color: Color(stroke.color.uiColor).opacity(0.5), radius: 3, x: 0, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
            }
        }
    }
}

struct DrawingOverlay: UIViewRepresentable {
    @Binding var currentStroke: DrawingStroke?
    @Binding var isDrawing: Bool
    let tool: DrawingTool
    let onStrokeCompleted: (DrawingStroke) -> Void
    
    func makeUIView(context: Context) -> DrawingTouchView {
        let view = DrawingTouchView()
        view.backgroundColor = .clear
        view.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: DrawingTouchView, context: Context) {
        context.coordinator.tool = tool
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentStroke: $currentStroke,
            isDrawing: $isDrawing,
            tool: tool,
            onStrokeCompleted: onStrokeCompleted
        )
    }
    
    class Coordinator: DrawingTouchViewDelegate {
        @Binding var currentStroke: DrawingStroke?
        @Binding var isDrawing: Bool
        var tool: DrawingTool
        let onStrokeCompleted: (DrawingStroke) -> Void
        
        init(currentStroke: Binding<DrawingStroke?>,
             isDrawing: Binding<Bool>,
             tool: DrawingTool,
             onStrokeCompleted: @escaping (DrawingStroke) -> Void) {
            self._currentStroke = currentStroke
            self._isDrawing = isDrawing
            self.tool = tool
            self.onStrokeCompleted = onStrokeCompleted
        }
        
        func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
            isDrawing = true
            currentStroke = DrawingStroke(
                color: tool.color,
                thickness: tool.thickness
            )
            
            let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
            currentStroke?.points.append(drawingPoint)
        }
        
        func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
            guard isDrawing else { return }
            
            let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
            currentStroke?.points.append(drawingPoint)
        }
        
        func drawingEnded() {
            guard let stroke = currentStroke, !stroke.points.isEmpty else { return }
            
            isDrawing = false
            onStrokeCompleted(stroke)
            currentStroke = nil
        }
    }
}

protocol DrawingTouchViewDelegate: AnyObject {
    func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
    func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
    func drawingEnded()
}

class DrawingTouchView: UIView {
    weak var delegate: DrawingTouchViewDelegate?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let point = touch.location(in: self)
        let normalizedPoint = CGPoint(
            x: point.x / bounds.width,
            y: point.y / bounds.height
        )
        let force = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0
        
        delegate?.drawingBegan(at: point, normalizedPoint: normalizedPoint, force: force)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let point = touch.location(in: self)
        let normalizedPoint = CGPoint(
            x: point.x / bounds.width,
            y: point.y / bounds.height
        )
        let force = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0
        
        delegate?.drawingMoved(to: point, normalizedPoint: normalizedPoint, force: force)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.drawingEnded()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.drawingEnded()
    }
}

struct DrawingToolbar: View {
    @Binding var tool: DrawingTool
    let onClear: () -> Void
    let onToggleToolbar: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DrawingTool.colors, id: \.self) { color in
                        Button(action: { tool.color = color }) {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(tool.color == color ? Color.white : Color.clear, lineWidth: 3)
                                )
                        }
                    }
                }
            }
            
            VStack(spacing: 8) {
                Text("Brush Size")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 16) {
                    ForEach(Array(DrawingTool.thicknesses.enumerated()), id: \.offset) { index, thickness in
                        VStack(spacing: 4) {
                            Button(action: { tool.thickness = thickness }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: CGFloat(14 + index * 7), height: CGFloat(14 + index * 7))
                                    .opacity(tool.thickness == thickness ? 1.0 : 0.5)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.blue, lineWidth: tool.thickness == thickness ? 2 : 0)
                                    )
                            }
                            
                            Text(index == 0 ? "Near" : index == 3 ? "Far" : "")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: onClear) {
                            VStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.white)
                                Text("Clear")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                        }
                        
                        Button(action: onToggleToolbar) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.gray.opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
}






















