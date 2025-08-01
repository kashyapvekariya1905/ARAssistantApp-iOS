
import SwiftUI
import SceneKit

struct AidDrawingView: View {
   @StateObject private var socketManager = SocketManager.shared
   @StateObject private var audioManager = AudioManager.shared
   @StateObject private var audioSocketHandler = AudioSocketHandler.shared
   @State private var currentImage: UIImage?
   @State private var feedbackImage: UIImage?
   @State private var frameCount = 0
   @State private var fps: Double = 0
   @State private var currentStroke: DrawingStroke?
   @State private var isDrawing = false
   @State private var drawingTool = DrawingTool()
   @State private var showToolbar = true
   @State private var strokes2D: [DrawingStroke] = []
   @State private var strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)] = [:]
   @State private var show3DPreview = false
   @State private var viewRefreshID = UUID()
   @State private var saved2DStrokes: [DrawingStroke] = []
   @Environment(\.dismiss) private var dismiss

   private let fpsTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

   var displayImage: UIImage? {
       feedbackImage ?? currentImage
   }

   var body: some View {
       ZStack {
           Color.black.edgesIgnoringSafeArea(.all)

           if let image = displayImage {
               Image(uiImage: image)
                   .resizable()
                   .aspectRatio(contentMode: .fill)
                   .edgesIgnoringSafeArea(.all)
                   .clipped()
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

           GeometryReader { geometry in
               DrawingView(
                   strokes2D: show3DPreview ? [] : strokes2D,
                   strokes3D: show3DPreview ? strokes3D : [:],
                   currentStroke: isDrawing && !show3DPreview ? currentStroke : nil,
                   viewSize: geometry.size,
                   show3D: show3DPreview
               )
               .allowsHitTesting(false)
               .id(viewRefreshID)
           }

           DrawingOverlay(
               currentStroke: $currentStroke,
               isDrawing: $isDrawing,
               tool: drawingTool,
               onStrokeCompleted: { stroke in
                   if !show3DPreview {
                       strokes2D.append(stroke)
                       sendDrawing(stroke)
                   }
               }
           )
           .allowsHitTesting(displayImage != nil && !show3DPreview)

           VStack {
               HStack {
                   Button(action: disconnect) {
                       Image(systemName: "chevron.left")
                           .font(.system(size: 24))
                           .foregroundColor(.white)
                           .padding()
                           .background(Circle().fill(Color.black.opacity(0.3)))
                   }
                   .padding(.leading)

                   Spacer()

                   VStack(alignment: .trailing, spacing: 4) {
                       if fps > 0 {
                           Label("\(Int(fps)) FPS", systemImage: "speedometer")
                               .font(.caption)
                               .foregroundColor(.white)
                               .padding(.horizontal, 12)
                               .padding(.vertical, 6)
                               .background(Color.green.opacity(0.8))
                               .cornerRadius(4)
                       }

                       if feedbackImage != nil {
                           Label("AR View", systemImage: "viewfinder")
                               .font(.caption)
                               .foregroundColor(.white)
                               .padding(.horizontal, 12)
                               .padding(.vertical, 6)
                               .background(Color.purple)
                               .cornerRadius(4)
                       }

                       if !strokes3D.isEmpty {
                           Button(action: {
                               withAnimation(.easeInOut(duration: 0.3)) {
                                   if !show3DPreview {
                                       saved2DStrokes = strokes2D
                                       strokes2D.removeAll()
                                   } else {
                                       strokes2D = saved2DStrokes
                                       saved2DStrokes.removeAll()
                                   }
                                   show3DPreview.toggle()
                                   currentStroke = nil
                                   isDrawing = false
                                   viewRefreshID = UUID()
                               }
                           }) {
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
                           }
                           .padding(.horizontal, 16)
                           .padding(.vertical, 8)
                           .background(Color.black.opacity(0.6))
                           .cornerRadius(15)
                       }
                   }
                  
                   if showToolbar && !show3DPreview {
                       DrawingToolbar(
                           tool: $drawingTool,
                           onClear: clearDrawings,
                           onClear2: clear2DDrawings,
                           onToggleToolbar: { showToolbar.toggle() }
                       )
                   } else if !show3DPreview {
                       Button(action: { showToolbar.toggle() }) {
                           Image(systemName: "paintbrush.fill")
                               .font(.system(size: 30))
                               .foregroundColor(.white)
                               .frame(width: 70, height: 70)
                               .background(Circle().fill(Color.black.opacity(0.6)))
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
           setupReceivers()
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

   private func setupReceivers() {
       socketManager.onImageReceived = { image in
           DispatchQueue.main.async {
               if self.feedbackImage == nil {
                   self.currentImage = image
               }
               self.frameCount += 1
           }
       }

       socketManager.onFeedbackReceived = { image in
           DispatchQueue.main.async {
               self.feedbackImage = image
               self.frameCount += 1
           }
       }

       socketManager.onClearDrawings = {
           DispatchQueue.main.async {
               self.strokes2D.removeAll()
               self.saved2DStrokes.removeAll()
               self.strokes3D.removeAll()
               self.currentStroke = nil
               self.isDrawing = false
               self.show3DPreview = false
               self.viewRefreshID = UUID()
           }
       }

       socketManager.onDrawingReceived = { message in
           DispatchQueue.main.async {
               switch message.action {
               case .render3D:
                   
                   if let stroke = message.stroke,
                      let anchorData = message.anchorData {
                       self.strokes3D[stroke.id] = (stroke, anchorData)
                       if !self.show3DPreview && self.strokes3D.count == 1 {
                           self.saved2DStrokes = self.strokes2D
                           self.strokes2D.removeAll()
                           self.show3DPreview = true
                           self.viewRefreshID = UUID()
                       }
                   }
               default:
                   break
               }
           }
       }
   }

   private func sendDrawing(_ stroke: DrawingStroke) {
       let message = DrawingMessage(
           action: .add,
           drawingId: stroke.id,
           stroke: stroke
       )
       socketManager.sendDrawingMessage(message)
       strokes2D.removeAll()
       saved2DStrokes.removeAll()
       viewRefreshID = UUID()
   }

   private func clearDrawings() {
       strokes2D.removeAll()
       saved2DStrokes.removeAll()
       strokes3D.removeAll()
       currentStroke = nil
       isDrawing = false
       show3DPreview = false
       viewRefreshID = UUID()
       socketManager.sendClearDrawings()
   }
    
    private func clear2DDrawings() {
//        strokes2D.removeAll()
//        saved2DStrokes.removeAll()
//        viewRefreshID = UUID()
    }

   private func disconnect() {
       audioSocketHandler.endAudioCall()
       socketManager.disconnect()
       dismiss()
   }
}

struct DrawingView: UIViewRepresentable {
   let strokes2D: [DrawingStroke]
   let strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)]
   let currentStroke: DrawingStroke?
   let viewSize: CGSize
   let show3D: Bool

   func makeUIView(context: Context) -> UIView {
       let containerView = UIView()
       containerView.backgroundColor = .clear

       let view2D = UIView()
       view2D.backgroundColor = .clear
       containerView.addSubview(view2D)

       let view3D = SCNView()
       view3D.backgroundColor = .clear
       view3D.scene = SCNScene()
       view3D.autoenablesDefaultLighting = false
       containerView.addSubview(view3D)

       view2D.translatesAutoresizingMaskIntoConstraints = false
       view3D.translatesAutoresizingMaskIntoConstraints = false

       NSLayoutConstraint.activate([
           view2D.topAnchor.constraint(equalTo: containerView.topAnchor),
           view2D.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
           view2D.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
           view2D.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

           view3D.topAnchor.constraint(equalTo: containerView.topAnchor),
           view3D.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
           view3D.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
           view3D.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
       ])

       let cameraNode = SCNNode()
       cameraNode.camera = SCNCamera()
       cameraNode.camera?.usesOrthographicProjection = false
       cameraNode.camera?.fieldOfView = 60
       cameraNode.position = SCNVector3(0, 0.5, 2)
       cameraNode.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
       view3D.scene?.rootNode.addChildNode(cameraNode)

       view3D.pointOfView = cameraNode
       view3D.allowsCameraControl = true
       view3D.defaultCameraController.interactionMode = .orbitTurntable
       view3D.defaultCameraController.inertiaEnabled = true

       let lightNode = SCNNode()
       lightNode.light = SCNLight()
       lightNode.light?.type = .omni
       lightNode.light?.intensity = 1500
       lightNode.position = SCNVector3(0, 0, 2)
       view3D.scene?.rootNode.addChildNode(lightNode)

       let ambientLightNode = SCNNode()
       ambientLightNode.light = SCNLight()
       ambientLightNode.light?.type = .ambient
       ambientLightNode.light?.intensity = 500
       view3D.scene?.rootNode.addChildNode(ambientLightNode)

       context.coordinator.view2D = view2D
       context.coordinator.view3D = view3D

       return containerView
   }

   func updateUIView(_ containerView: UIView, context: Context) {
       guard let view2D = context.coordinator.view2D,
             let view3D = context.coordinator.view3D else { return }

       view2D.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
       view3D.scene?.rootNode.childNodes
           .filter { $0.name == "stroke" }
           .forEach { $0.removeFromParentNode() }

       var all2DStrokes = strokes2D
       if let current = currentStroke {
           all2DStrokes.append(current)
       }

       for stroke in all2DStrokes {
           draw2DStroke(stroke, in: view2D)
       }

       for (_, (stroke, anchorData)) in strokes3D {
           let strokeNode = create3DStroke(
               stroke: stroke,
               anchorTransform: anchorData.worldTransform.simdTransform,
               distance: anchorData.distance
           )
           strokeNode.name = "stroke"
           view3D.scene?.rootNode.addChildNode(strokeNode)
       }

       if show3D {
           view2D.isHidden = true
           view3D.isHidden = false
       } else {
           view2D.isHidden = false
           view3D.isHidden = true
       }
   }

   func makeCoordinator() -> Coordinator {
       Coordinator()
   }

   class Coordinator {
       var view2D: UIView?
       var view3D: SCNView?
   }

   private func draw2DStroke(_ stroke: DrawingStroke, in view: UIView) {
       guard stroke.points.count > 1 else { return }

       let path = UIBezierPath()
       let points = stroke.points.map { point in
           CGPoint(
               x: CGFloat(point.x) * view.bounds.width,
               y: CGFloat(point.y) * view.bounds.height
           )
       }

       path.move(to: points[0])
       for i in 1..<points.count {
           path.addLine(to: points[i])
       }

       let shapeLayer = CAShapeLayer()
       shapeLayer.path = path.cgPath
       shapeLayer.strokeColor = stroke.color.uiColor.cgColor
       shapeLayer.lineWidth = CGFloat(stroke.thickness * 1000)
       shapeLayer.fillColor = UIColor.clear.cgColor
       shapeLayer.lineCap = .round
       shapeLayer.lineJoin = .round

       view.layer.addSublayer(shapeLayer)
   }

   private func create3DStroke(stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
       let strokeNode = SCNNode()

       guard stroke.points.count > 1 else { return strokeNode }

       let scaleFactor = distance * 0.3
       let lineThickness = stroke.thickness * 0.5

       let minX = stroke.points.map { $0.x }.min() ?? 0
       let maxX = stroke.points.map { $0.x }.max() ?? 1
       let minY = stroke.points.map { $0.y }.min() ?? 0
       let maxY = stroke.points.map { $0.y }.max() ?? 1

       let centerX = (minX + maxX) / 2
       let centerY = (minY + maxY) / 2

       let aspectRatio = Float(viewSize.width / viewSize.height)

       var points3D: [SCNVector3] = []

       for point in stroke.points {
           let normalizedX = (point.x - centerX) * 2.0
           let normalizedY = -(point.y - centerY) * 2.0

           let scaledX = normalizedX * scaleFactor
           let scaledY = normalizedY * scaleFactor / aspectRatio

           points3D.append(SCNVector3(x: scaledX, y: scaledY, z: 0))
       }

       let smoothedPoints = smoothPath(points: points3D, iterations: 2)

       for i in 0..<(smoothedPoints.count - 1) {
           let start = smoothedPoints[i]
           let end = smoothedPoints[i + 1]

           let cylinder = createCylinderBetween(
               start: start,
               end: end,
               radius: lineThickness * 0.3,
               color: stroke.color.uiColor
           )
           strokeNode.addChildNode(cylinder)
       }

       for (index, point) in smoothedPoints.enumerated() {
           if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
               let sphere = SCNSphere(radius: CGFloat(lineThickness * 0.5))
               sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
               sphere.firstMaterial?.lightingModel = .constant
               sphere.firstMaterial?.emission.contents = stroke.color.uiColor
               sphere.firstMaterial?.emission.intensity = 0.2

               let sphereNode = SCNNode(geometry: sphere)
               sphereNode.position = point
               strokeNode.addChildNode(sphereNode)
           }
       }

       strokeNode.simdTransform = anchorTransform

       return strokeNode
   }

   private func smoothPath(points: [SCNVector3], iterations: Int = 1) -> [SCNVector3] {
       guard points.count > 2 else { return points }

       var smoothed = points

       for _ in 0..<iterations {
           var newPoints: [SCNVector3] = []
           newPoints.append(smoothed[0])

           for i in 1..<(smoothed.count - 1) {
               let prev = smoothed[i - 1]
               let curr = smoothed[i]
               let next = smoothed[i + 1]

               let smoothX = (prev.x + 2 * curr.x + next.x) / 4
               let smoothY = (prev.y + 2 * curr.y + next.y) / 4
               let smoothZ = (prev.z + 2 * curr.z + next.z) / 4

               newPoints.append(SCNVector3(x: smoothX, y: smoothY, z: smoothZ))
           }

           newPoints.append(smoothed.last!)
           smoothed = newPoints
       }

       return smoothed
   }

   private func createCylinderBetween(start: SCNVector3, end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
       let distance = simd_distance(
           simd_float3(start.x, start.y, start.z),
           simd_float3(end.x, end.y, end.z)
       )

       guard distance > 0 else { return SCNNode() }

       let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(distance))
       cylinder.radialSegmentCount = 16

       let material = SCNMaterial()
       material.diffuse.contents = color
       material.lightingModel = .constant
       material.isDoubleSided = true
       material.emission.contents = color
       material.emission.intensity = 0.2
       material.shininess = 0.0

       cylinder.materials = [material]

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
    let onClear2: () -> Void
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
                                   .font(.system(size: 8))
                                   .foregroundColor(.white)
                           }
                           .padding(8)
                           .frame(width: 55, height: 40)
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

