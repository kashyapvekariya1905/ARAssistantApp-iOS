//
//import SwiftUI
//import SceneKit
//
//struct AidDrawingView: View {
//   @StateObject private var socketManager = SocketManager.shared
//   @StateObject private var audioManager = AudioManager.shared
//   @StateObject private var audioSocketHandler = AudioSocketHandler.shared
//   @State private var currentImage: UIImage?
//   @State private var feedbackImage: UIImage?
//   @State private var frameCount = 0
//   @State private var fps: Double = 0
//   @State private var currentStroke: DrawingStroke?
//   @State private var isDrawing = false
//   @State private var drawingTool = DrawingTool()
//   @State private var showToolbar = true
//   @State private var strokes2D: [DrawingStroke] = []
//   @State private var strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)] = [:]
//   @State private var show3DPreview = false
//   @State private var viewRefreshID = UUID()
//   @State private var saved2DStrokes: [DrawingStroke] = []
//   @Environment(\.dismiss) private var dismiss
//
//   private let fpsTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
//
//   var displayImage: UIImage? {
//       feedbackImage ?? currentImage
//   }
//
//   var body: some View {
//       ZStack {
//           Color.black.edgesIgnoringSafeArea(.all)
//
//           if let image = displayImage {
//               Image(uiImage: image)
//                   .resizable()
//                   .aspectRatio(contentMode: .fill)
//                   .edgesIgnoringSafeArea(.all)
//                   .clipped()
//           } else {
//               VStack {
//                   Image(systemName: "video.slash")
//                       .font(.system(size: 60))
//                       .foregroundColor(.gray)
//                   Text("Waiting for stream...")
//                       .foregroundColor(.gray)
//                       .padding()
//               }
//           }
//
//           GeometryReader { geometry in
//               DrawingView(
//                   strokes2D: show3DPreview ? [] : strokes2D,
//                   strokes3D: show3DPreview ? strokes3D : [:],
//                   currentStroke: isDrawing && !show3DPreview ? currentStroke : nil,
//                   viewSize: geometry.size,
//                   show3D: show3DPreview
//               )
//               .allowsHitTesting(false)
//               .id(viewRefreshID)
//           }
//
//           DrawingOverlay(
//               currentStroke: $currentStroke,
//               isDrawing: $isDrawing,
//               tool: drawingTool,
//               onStrokeCompleted: { stroke in
//                   if !show3DPreview {
//                       strokes2D.append(stroke)
//                       sendDrawing(stroke)
//                   }
//               }
//           )
//           .allowsHitTesting(displayImage != nil && !show3DPreview)
//
//           VStack {
//               HStack {
//                   Button(action: disconnect) {
//                       Image(systemName: "chevron.left")
//                           .font(.system(size: 24))
//                           .foregroundColor(.white)
//                           .padding()
//                           .background(Circle().fill(Color.black.opacity(0.3)))
//                   }
//                   .padding(.leading)
//
//                   Spacer()
//
//                   VStack(alignment: .trailing, spacing: 4) {
//                       if fps > 0 {
//                           Label("\(Int(fps)) FPS", systemImage: "speedometer")
//                               .font(.caption)
//                               .foregroundColor(.white)
//                               .padding(.horizontal, 12)
//                               .padding(.vertical, 6)
//                               .background(Color.green.opacity(0.8))
//                               .cornerRadius(4)
//                       }
//
//                       if feedbackImage != nil {
//                           Label("AR View", systemImage: "viewfinder")
//                               .font(.caption)
//                               .foregroundColor(.white)
//                               .padding(.horizontal, 12)
//                               .padding(.vertical, 6)
//                               .background(Color.purple)
//                               .cornerRadius(4)
//                       }
//
//                       if !strokes3D.isEmpty {
//                           Button(action: {
//                               withAnimation(.easeInOut(duration: 0.3)) {
//                                   if !show3DPreview {
//                                       saved2DStrokes = strokes2D
//                                       strokes2D.removeAll()
//                                   } else {
//                                       strokes2D = saved2DStrokes
//                                       saved2DStrokes.removeAll()
//                                   }
//                                   show3DPreview.toggle()
//                                   currentStroke = nil
//                                   isDrawing = false
//                                   viewRefreshID = UUID()
//                               }
//                           }) {
//                               HStack(spacing: 4) {
//                                   Image(systemName: show3DPreview ? "cube.fill" : "square.fill")
//                                       .font(.caption)
//                                   Text(show3DPreview ? "3D" : "2D")
//                                       .font(.caption.bold())
//                               }
//                               .padding(.horizontal, 12)
//                               .padding(.vertical, 6)
//                               .background(show3DPreview ? Color.blue : Color.gray)
//                               .foregroundColor(.white)
//                               .cornerRadius(6)
//                           }
//                       }
//                   }
//                   .padding(.trailing)
//               }
//               .padding(.top, 50)
//
//               Spacer()
//
//               VStack(spacing: 20) {
//                   if audioManager.isCallActive {
//                       VStack(spacing: 12) {
//                           HStack {
//                               Image(systemName: audioManager.isCallOnHold ? "pause.circle.fill" : "phone.fill")
//                                   .foregroundColor(audioManager.isCallOnHold ? .orange : .green)
//                               Text(audioManager.isCallOnHold ? "Call On Hold" : "Call Active")
//                                   .foregroundColor(.white)
//                           }
//                           .padding(.horizontal, 16)
//                           .padding(.vertical, 8)
//                           .background(Color.black.opacity(0.6))
//                           .cornerRadius(20)
//                          
//                           HStack(spacing: 16) {
//                               Button(action: {
//                                   audioManager.toggleMic()
//                               }) {
//                                   VStack {
//                                       Image(systemName: audioManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
//                                           .font(.system(size: 20))
//                                       Text(audioManager.isMicMuted ? "Unmute" : "Mute")
//                                           .font(.system(size: 10))
//                                   }
//                                   .frame(width: 50, height: 50)
//                                   .foregroundColor(.white)
//                                   .background(audioManager.isMicMuted ? Color.red : Color.gray.opacity(0.6))
//                                   .clipShape(Circle())
//                               }
//                              
//                               Button(action: {
//                                   audioManager.toggleHold()
//                               }) {
//                                   VStack {
//                                       Image(systemName: audioManager.isCallOnHold ? "play.fill" : "pause.fill")
//                                           .font(.system(size: 20))
//                                       Text(audioManager.isCallOnHold ? "Resume" : "Hold")
//                                           .font(.system(size: 10))
//                                   }
//                                   .frame(width: 50, height: 50)
//                                   .foregroundColor(.white)
//                                   .background(audioManager.isCallOnHold ? Color.orange : Color.gray.opacity(0.6))
//                                   .clipShape(Circle())
//                               }
//                              
//                               Button(action: {
//                                   audioSocketHandler.endAudioCall()
//                               }) {
//                                   VStack {
//                                       Image(systemName: "phone.down.fill")
//                                           .font(.system(size: 20))
//                                       Text("End")
//                                           .font(.system(size: 10))
//                                   }
//                                   .frame(width: 50, height: 50)
//                                   .foregroundColor(.white)
//                                   .background(Color.red)
//                                   .clipShape(Circle())
//                               }
//                           }
//                           .padding(.horizontal, 16)
//                           .padding(.vertical, 8)
//                           .background(Color.black.opacity(0.6))
//                           .cornerRadius(15)
//                       }
//                   }
//                  
//                   if showToolbar && !show3DPreview {
//                       DrawingToolbar(
//                           tool: $drawingTool,
//                           onClear: clearDrawings,
//                           onClear2: clear2DDrawings,
//                           onToggleToolbar: { showToolbar.toggle() }
//                       )
//                   } else if !show3DPreview {
//                       Button(action: { showToolbar.toggle() }) {
//                           Image(systemName: "paintbrush.fill")
//                               .font(.system(size: 30))
//                               .foregroundColor(.white)
//                               .frame(width: 70, height: 70)
//                               .background(Circle().fill(Color.black.opacity(0.6)))
//                       }
//                   }
//                  
//                   Text(socketManager.connectionStatus)
//                       .font(.caption)
//                       .foregroundColor(.white)
//                       .padding(.horizontal, 12)
//                       .padding(.vertical, 6)
//                       .background(Color.black.opacity(0.6))
//                       .cornerRadius(12)
//               }
//               .padding(.bottom, 40)
//           }
//       }
//       .navigationBarHidden(true)
//       .onAppear {
//           setupReceivers()
//           if !socketManager.isConnected {
//               socketManager.connect(as: "aid")
//               DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                   audioSocketHandler.startAudioCall()
//               }
//           }
//       }
//       .onDisappear {
//           disconnect()
//       }
//       .onReceive(fpsTimer) { _ in
//           fps = Double(frameCount)
//           frameCount = 0
//       }
//   }
//
//   private func setupReceivers() {
//       socketManager.onImageReceived = { image in
//           DispatchQueue.main.async {
//               if self.feedbackImage == nil {
//                   self.currentImage = image
//               }
//               self.frameCount += 1
//           }
//       }
//
//       socketManager.onFeedbackReceived = { image in
//           DispatchQueue.main.async {
//               self.feedbackImage = image
//               self.frameCount += 1
//           }
//       }
//
//       socketManager.onClearDrawings = {
//           DispatchQueue.main.async {
//               self.strokes2D.removeAll()
//               self.saved2DStrokes.removeAll()
//               self.strokes3D.removeAll()
//               self.currentStroke = nil
//               self.isDrawing = false
//               self.show3DPreview = false
//               self.viewRefreshID = UUID()
//           }
//       }
//
//       socketManager.onDrawingReceived = { message in
//           DispatchQueue.main.async {
//               switch message.action {
//               case .render3D:
//                   
//                   if let stroke = message.stroke,
//                      let anchorData = message.anchorData {
//                       self.strokes3D[stroke.id] = (stroke, anchorData)
//                       if !self.show3DPreview && self.strokes3D.count == 1 {
//                           self.saved2DStrokes = self.strokes2D
//                           self.strokes2D.removeAll()
//                           self.show3DPreview = true
//                           self.viewRefreshID = UUID()
//                       }
//                   }
//               default:
//                   break
//               }
//           }
//       }
//   }
//
//   private func sendDrawing(_ stroke: DrawingStroke) {
//       let message = DrawingMessage(
//           action: .add,
//           drawingId: stroke.id,
//           stroke: stroke
//       )
//       socketManager.sendDrawingMessage(message)
//       strokes2D.removeAll()
//       saved2DStrokes.removeAll()
//       viewRefreshID = UUID()
//   }
//
//   private func clearDrawings() {
//       strokes2D.removeAll()
//       saved2DStrokes.removeAll()
//       strokes3D.removeAll()
//       currentStroke = nil
//       isDrawing = false
//       show3DPreview = false
//       viewRefreshID = UUID()
//       socketManager.sendClearDrawings()
//   }
//    
//    private func clear2DDrawings() {
////        strokes2D.removeAll()
////        saved2DStrokes.removeAll()
////        viewRefreshID = UUID()
//    }
//
//   private func disconnect() {
//       audioSocketHandler.endAudioCall()
//       socketManager.disconnect()
//       dismiss()
//   }
//}
//
//struct DrawingView: UIViewRepresentable {
//   let strokes2D: [DrawingStroke]
//   let strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)]
//   let currentStroke: DrawingStroke?
//   let viewSize: CGSize
//   let show3D: Bool
//
//   func makeUIView(context: Context) -> UIView {
//       let containerView = UIView()
//       containerView.backgroundColor = .clear
//
//       let view2D = UIView()
//       view2D.backgroundColor = .clear
//       containerView.addSubview(view2D)
//
//       let view3D = SCNView()
//       view3D.backgroundColor = .clear
//       view3D.scene = SCNScene()
//       view3D.autoenablesDefaultLighting = false
//       containerView.addSubview(view3D)
//
//       view2D.translatesAutoresizingMaskIntoConstraints = false
//       view3D.translatesAutoresizingMaskIntoConstraints = false
//
//       NSLayoutConstraint.activate([
//           view2D.topAnchor.constraint(equalTo: containerView.topAnchor),
//           view2D.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//           view2D.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//           view2D.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
//
//           view3D.topAnchor.constraint(equalTo: containerView.topAnchor),
//           view3D.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//           view3D.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//           view3D.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
//       ])
//
//       let cameraNode = SCNNode()
//       cameraNode.camera = SCNCamera()
//       cameraNode.camera?.usesOrthographicProjection = false
//       cameraNode.camera?.fieldOfView = 60
//       cameraNode.position = SCNVector3(0, 0.5, 2)
//       cameraNode.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
//       view3D.scene?.rootNode.addChildNode(cameraNode)
//
//       view3D.pointOfView = cameraNode
//       view3D.allowsCameraControl = true
//       view3D.defaultCameraController.interactionMode = .orbitTurntable
//       view3D.defaultCameraController.inertiaEnabled = true
//
//       let lightNode = SCNNode()
//       lightNode.light = SCNLight()
//       lightNode.light?.type = .omni
//       lightNode.light?.intensity = 1500
//       lightNode.position = SCNVector3(0, 0, 2)
//       view3D.scene?.rootNode.addChildNode(lightNode)
//
//       let ambientLightNode = SCNNode()
//       ambientLightNode.light = SCNLight()
//       ambientLightNode.light?.type = .ambient
//       ambientLightNode.light?.intensity = 500
//       view3D.scene?.rootNode.addChildNode(ambientLightNode)
//
//       context.coordinator.view2D = view2D
//       context.coordinator.view3D = view3D
//
//       return containerView
//   }
//
//   func updateUIView(_ containerView: UIView, context: Context) {
//       guard let view2D = context.coordinator.view2D,
//             let view3D = context.coordinator.view3D else { return }
//
//       view2D.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
//       view3D.scene?.rootNode.childNodes
//           .filter { $0.name == "stroke" }
//           .forEach { $0.removeFromParentNode() }
//
//       var all2DStrokes = strokes2D
//       if let current = currentStroke {
//           all2DStrokes.append(current)
//       }
//
//       for stroke in all2DStrokes {
//           draw2DStroke(stroke, in: view2D)
//       }
//
//       for (_, (stroke, anchorData)) in strokes3D {
//           let strokeNode = create3DStroke(
//               stroke: stroke,
//               anchorTransform: anchorData.worldTransform.simdTransform,
//               distance: anchorData.distance
//           )
//           strokeNode.name = "stroke"
//           view3D.scene?.rootNode.addChildNode(strokeNode)
//       }
//
//       if show3D {
//           view2D.isHidden = true
//           view3D.isHidden = false
//       } else {
//           view2D.isHidden = false
//           view3D.isHidden = true
//       }
//   }
//
//   func makeCoordinator() -> Coordinator {
//       Coordinator()
//   }
//
//   class Coordinator {
//       var view2D: UIView?
//       var view3D: SCNView?
//   }
//
//   private func draw2DStroke(_ stroke: DrawingStroke, in view: UIView) {
//       guard stroke.points.count > 1 else { return }
//
//       let path = UIBezierPath()
//       let points = stroke.points.map { point in
//           CGPoint(
//               x: CGFloat(point.x) * view.bounds.width,
//               y: CGFloat(point.y) * view.bounds.height
//           )
//       }
//
//       path.move(to: points[0])
//       for i in 1..<points.count {
//           path.addLine(to: points[i])
//       }
//
//       let shapeLayer = CAShapeLayer()
//       shapeLayer.path = path.cgPath
//       shapeLayer.strokeColor = stroke.color.uiColor.cgColor
//       shapeLayer.lineWidth = CGFloat(stroke.thickness * 1000)
//       shapeLayer.fillColor = UIColor.clear.cgColor
//       shapeLayer.lineCap = .round
//       shapeLayer.lineJoin = .round
//
//       view.layer.addSublayer(shapeLayer)
//   }
//
//   private func create3DStroke(stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
//       let strokeNode = SCNNode()
//
//       guard stroke.points.count > 1 else { return strokeNode }
//
//       let scaleFactor = distance * 0.3
//       let lineThickness = stroke.thickness * 0.5
//
//       let minX = stroke.points.map { $0.x }.min() ?? 0
//       let maxX = stroke.points.map { $0.x }.max() ?? 1
//       let minY = stroke.points.map { $0.y }.min() ?? 0
//       let maxY = stroke.points.map { $0.y }.max() ?? 1
//
//       let centerX = (minX + maxX) / 2
//       let centerY = (minY + maxY) / 2
//
//       let aspectRatio = Float(viewSize.width / viewSize.height)
//
//       var points3D: [SCNVector3] = []
//
//       for point in stroke.points {
//           let normalizedX = (point.x - centerX) * 2.0
//           let normalizedY = -(point.y - centerY) * 2.0
//
//           let scaledX = normalizedX * scaleFactor
//           let scaledY = normalizedY * scaleFactor / aspectRatio
//
//           points3D.append(SCNVector3(x: scaledX, y: scaledY, z: 0))
//       }
//
//       let smoothedPoints = smoothPath(points: points3D, iterations: 2)
//
//       for i in 0..<(smoothedPoints.count - 1) {
//           let start = smoothedPoints[i]
//           let end = smoothedPoints[i + 1]
//
//           let cylinder = createCylinderBetween(
//               start: start,
//               end: end,
//               radius: lineThickness * 0.3,
//               color: stroke.color.uiColor
//           )
//           strokeNode.addChildNode(cylinder)
//       }
//
//       for (index, point) in smoothedPoints.enumerated() {
//           if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
//               let sphere = SCNSphere(radius: CGFloat(lineThickness * 0.5))
//               sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
//               sphere.firstMaterial?.lightingModel = .constant
//               sphere.firstMaterial?.emission.contents = stroke.color.uiColor
//               sphere.firstMaterial?.emission.intensity = 0.2
//
//               let sphereNode = SCNNode(geometry: sphere)
//               sphereNode.position = point
//               strokeNode.addChildNode(sphereNode)
//           }
//       }
//
//       strokeNode.simdTransform = anchorTransform
//
//       return strokeNode
//   }
//
//   private func smoothPath(points: [SCNVector3], iterations: Int = 1) -> [SCNVector3] {
//       guard points.count > 2 else { return points }
//
//       var smoothed = points
//
//       for _ in 0..<iterations {
//           var newPoints: [SCNVector3] = []
//           newPoints.append(smoothed[0])
//
//           for i in 1..<(smoothed.count - 1) {
//               let prev = smoothed[i - 1]
//               let curr = smoothed[i]
//               let next = smoothed[i + 1]
//
//               let smoothX = (prev.x + 2 * curr.x + next.x) / 4
//               let smoothY = (prev.y + 2 * curr.y + next.y) / 4
//               let smoothZ = (prev.z + 2 * curr.z + next.z) / 4
//
//               newPoints.append(SCNVector3(x: smoothX, y: smoothY, z: smoothZ))
//           }
//
//           newPoints.append(smoothed.last!)
//           smoothed = newPoints
//       }
//
//       return smoothed
//   }
//
//   private func createCylinderBetween(start: SCNVector3, end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
//       let distance = simd_distance(
//           simd_float3(start.x, start.y, start.z),
//           simd_float3(end.x, end.y, end.z)
//       )
//
//       guard distance > 0 else { return SCNNode() }
//
//       let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(distance))
//       cylinder.radialSegmentCount = 16
//
//       let material = SCNMaterial()
//       material.diffuse.contents = color
//       material.lightingModel = .constant
//       material.isDoubleSided = true
//       material.emission.contents = color
//       material.emission.intensity = 0.2
//       material.shininess = 0.0
//
//       cylinder.materials = [material]
//
//       let cylinderNode = SCNNode(geometry: cylinder)
//
//       cylinderNode.position = SCNVector3(
//           x: (start.x + end.x) / 2,
//           y: (start.y + end.y) / 2,
//           z: (start.z + end.z) / 2
//       )
//
//       let direction = simd_normalize(
//           simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
//       )
//
//       let up = simd_float3(0, 1, 0)
//       let dot = simd_dot(up, direction)
//
//       if abs(dot) > 0.999 {
//           cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
//       } else {
//           let axis = simd_normalize(simd_cross(up, direction))
//           let angle = acos(dot)
//           cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
//       }
//
//       return cylinderNode
//   }
//}
//
//struct DrawingOverlay: UIViewRepresentable {
//   @Binding var currentStroke: DrawingStroke?
//   @Binding var isDrawing: Bool
//   let tool: DrawingTool
//   let onStrokeCompleted: (DrawingStroke) -> Void
//
//   func makeUIView(context: Context) -> DrawingTouchView {
//       let view = DrawingTouchView()
//       view.backgroundColor = .clear
//       view.delegate = context.coordinator
//       return view
//   }
//
//   func updateUIView(_ uiView: DrawingTouchView, context: Context) {
//       context.coordinator.tool = tool
//   }
//
//   func makeCoordinator() -> Coordinator {
//       Coordinator(
//           currentStroke: $currentStroke,
//           isDrawing: $isDrawing,
//           tool: tool,
//           onStrokeCompleted: onStrokeCompleted
//       )
//   }
//
//   class Coordinator: DrawingTouchViewDelegate {
//       @Binding var currentStroke: DrawingStroke?
//       @Binding var isDrawing: Bool
//       var tool: DrawingTool
//       let onStrokeCompleted: (DrawingStroke) -> Void
//
//       init(currentStroke: Binding<DrawingStroke?>,
//            isDrawing: Binding<Bool>,
//            tool: DrawingTool,
//            onStrokeCompleted: @escaping (DrawingStroke) -> Void) {
//           self._currentStroke = currentStroke
//           self._isDrawing = isDrawing
//           self.tool = tool
//           self.onStrokeCompleted = onStrokeCompleted
//       }
//
//       func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
//           isDrawing = true
//           currentStroke = DrawingStroke(
//               color: tool.color,
//               thickness: tool.thickness
//           )
//
//           let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
//           currentStroke?.points.append(drawingPoint)
//       }
//
//       func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
//           guard isDrawing else { return }
//
//           let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
//           currentStroke?.points.append(drawingPoint)
//       }
//
//       func drawingEnded() {
//           guard let stroke = currentStroke, !stroke.points.isEmpty else { return }
//
//           isDrawing = false
//           onStrokeCompleted(stroke)
//           currentStroke = nil
//           
//           
//       }
//   }
//}
//
//protocol DrawingTouchViewDelegate: AnyObject {
//   func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
//   func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
//   func drawingEnded()
//}
//
//class DrawingTouchView: UIView {
//   weak var delegate: DrawingTouchViewDelegate?
//
//   override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//       guard let touch = touches.first else { return }
//
//       let point = touch.location(in: self)
//       let normalizedPoint = CGPoint(
//           x: point.x / bounds.width,
//           y: point.y / bounds.height
//       )
//       let force = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0
//
//       delegate?.drawingBegan(at: point, normalizedPoint: normalizedPoint, force: force)
//   }
//
//   override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//       guard let touch = touches.first else { return }
//
//       let point = touch.location(in: self)
//       let normalizedPoint = CGPoint(
//           x: point.x / bounds.width,
//           y: point.y / bounds.height
//       )
//       let force = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0
//
//       delegate?.drawingMoved(to: point, normalizedPoint: normalizedPoint, force: force)
//   }
//
//   override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//       delegate?.drawingEnded()
//       
//   }
//
//   override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//       delegate?.drawingEnded()
//   }
//}
//
//struct DrawingToolbar: View {
//   @Binding var tool: DrawingTool
//   let onClear: () -> Void
//    let onClear2: () -> Void
//   let onToggleToolbar: () -> Void
//
//   var body: some View {
//       VStack(spacing: 12) {
//           ScrollView(.horizontal, showsIndicators: false) {
//               HStack(spacing: 12) {
//                   ForEach(DrawingTool.colors, id: \.self) { color in
//                       Button(action: { tool.color = color }) {
//                           Circle()
//                               .fill(Color(color))
//                               .frame(width: 40, height: 40)
//                               .overlay(
//                                   Circle()
//                                       .stroke(tool.color == color ? Color.white : Color.clear, lineWidth: 3)
//                               )
//                       }
//                   }
//               }
//           }
//
//           VStack(spacing: 8) {
//               Text("Brush Size")
//                   .font(.caption)
//                   .foregroundColor(.white.opacity(0.9))
//
//               HStack(spacing: 16) {
//                   ForEach(Array(DrawingTool.thicknesses.enumerated()), id: \.offset) { index, thickness in
//                       VStack(spacing: 4) {
//                           Button(action: { tool.thickness = thickness }) {
//                               Circle()
//                                   .fill(Color.white)
//                                   .frame(width: CGFloat(14 + index * 7), height: CGFloat(14 + index * 7))
//                                   .opacity(tool.thickness == thickness ? 1.0 : 0.5)
//                                   .overlay(
//                                       Circle()
//                                           .stroke(Color.blue, lineWidth: tool.thickness == thickness ? 2 : 0)
//                                   )
//                           }
//
//                           Text(index == 0 ? "Near" : index == 3 ? "Far" : "")
//                               .font(.system(size: 8))
//                               .foregroundColor(.white.opacity(0.7))
//                       }
//                   }
//
//                   Spacer()
//
//                   HStack(spacing: 12) {
//                       Button(action: onClear) {
//                           VStack {
//                               Image(systemName: "trash")
//                                   .foregroundColor(.white)
//                               Text("Clear")
//                                   .font(.system(size: 8))
//                                   .foregroundColor(.white)
//                           }
//                           .padding(8)
//                           .frame(width: 55, height: 40)
//                           .background(Color.red.opacity(0.8))
//                           .cornerRadius(8)
//                       }
//
//                       Button(action: onToggleToolbar) {
//                           Image(systemName: "chevron.down")
//                               .foregroundColor(.white)
//                               .padding(8)
//                               .background(Color.gray.opacity(0.8))
//                               .clipShape(Circle())
//                       }
//                   }
//               }
//           }
//       }
//       .padding()
//       .background(Color.black.opacity(0.8))
//       .cornerRadius(20)
//   }
//}









import SwiftUI
import SceneKit

/**
 * AidDrawingView is the main interface for AR-assisted drawing with real-time video streaming
 *
 * This view combines:
 * - Live video feed from a remote camera
 * - 2D drawing overlay capabilities
 * - 3D drawing visualization with AR anchoring
 * - Audio call functionality
 * - Real-time communication via WebSocket
 */


struct AidDrawingView: View {
   // MARK: - State Objects (Singleton Managers)
   @StateObject private var socketManager = SocketManager.shared        // WebSocket connection manager
   @StateObject private var audioManager = AudioManager.shared          // Audio call state management
   @StateObject private var audioSocketHandler = AudioSocketHandler.shared  // Audio data transmission
   
   // MARK: - Image and Video State
   @State private var currentImage: UIImage?         // Current frame from video stream
   @State private var feedbackImage: UIImage?        // AR feedback overlay image from remote
   
   // MARK: - Performance Monitoring
   @State private var frameCount = 0                 // Counter for FPS calculation
   @State private var fps: Double = 0               // Current frames per second display
   
   // MARK: - Drawing State
   @State private var currentStroke: DrawingStroke?  // Currently active drawing stroke
   @State private var isDrawing = false             // Whether user is actively drawing
   @State private var drawingTool = DrawingTool()   // Current drawing tool (color, thickness)
   @State private var showToolbar = true            // Visibility of drawing toolbar
   
   // MARK: - Drawing Storage Arrays
   @State private var strokes2D: [DrawingStroke] = []    // 2D overlay strokes
   @State private var strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)] = [:]  // 3D anchored strokes with metadata
   
   // MARK: - View State Management
   @State private var show3DPreview = false         // Toggle between 2D overlay and 3D view mode
   @State private var viewRefreshID = UUID()        // Forces view refresh when changed
   @State private var saved2DStrokes: [DrawingStroke] = []  // Temporary storage when switching to 3D mode
   
   // MARK: - Environment
   @Environment(\.dismiss) private var dismiss       // SwiftUI dismiss function

   // MARK: - Timer for FPS Monitoring
   private let fpsTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

   /**
    * Computed property that returns the primary image to display
    * Priority: AR feedback image > current stream image > nil
    */
   var displayImage: UIImage? {
       feedbackImage ?? currentImage
   }

   var body: some View {
       ZStack {
           // MARK: - Background and Video Display
           Color.black.edgesIgnoringSafeArea(.all)

           // Display video stream or loading state
           if let image = displayImage {
               Image(uiImage: image)
                   .resizable()
                   .aspectRatio(contentMode: .fill)  // Fill screen while maintaining aspect ratio
                   .edgesIgnoringSafeArea(.all)
                   .clipped()                        // Clip overflow
           } else {
               // Loading state when no video stream available
               VStack {
                   Image(systemName: "video.slash")
                       .font(.system(size: 60))
                       .foregroundColor(.gray)
                   Text("Waiting for stream...")
                       .foregroundColor(.gray)
                       .padding()
               }
           }

           // MARK: - Drawing Layer
           GeometryReader { geometry in
               DrawingView(
                   strokes2D: show3DPreview ? [] : strokes2D,           // Show 2D strokes only in 2D mode
                   strokes3D: show3DPreview ? strokes3D : [:],         // Show 3D strokes only in 3D mode
                   currentStroke: isDrawing && !show3DPreview ? currentStroke : nil,  // Show current stroke only when drawing in 2D
                   viewSize: geometry.size,                            // Pass view dimensions for scaling
                   show3D: show3DPreview                              // Current display mode
               )
               .allowsHitTesting(false)      // Drawing handled by overlay, this is display only
               .id(viewRefreshID)            // Force refresh when ID changes
           }

           // MARK: - Touch Input Overlay
           DrawingOverlay(
               currentStroke: $currentStroke,
               isDrawing: $isDrawing,
               tool: drawingTool,
               onStrokeCompleted: { stroke in
                   // Only process strokes in 2D mode
                   if !show3DPreview {
                       strokes2D.append(stroke)    // Add to local display
                       sendDrawing(stroke)         // Send to remote via WebSocket
                   }
               }
           )
           .allowsHitTesting(displayImage != nil && !show3DPreview)  // Only accept touches when video is available and in 2D mode

           // MARK: - UI Overlay Elements
           VStack {
               // MARK: - Top Bar with Navigation and Status
               HStack {
                   // Back/disconnect button
                   Button(action: disconnect) {
                       Image(systemName: "chevron.left")
                           .font(.system(size: 24))
                           .foregroundColor(.white)
                           .padding()
                           .background(Circle().fill(Color.black.opacity(0.3)))
                   }
                   .padding(.leading)

                   Spacer()

                   // Status indicators (FPS, AR mode, 3D toggle)
                   VStack(alignment: .trailing, spacing: 4) {
                       // FPS indicator (only show when receiving frames)
                       if fps > 0 {
                           Label("\(Int(fps)) FPS", systemImage: "speedometer")
                               .font(.caption)
                               .foregroundColor(.white)
                               .padding(.horizontal, 12)
                               .padding(.vertical, 6)
                               .background(Color.green.opacity(0.8))
                               .cornerRadius(4)
                       }

                       // AR feedback mode indicator
                       if feedbackImage != nil {
                           Label("AR View", systemImage: "viewfinder")
                               .font(.caption)
                               .foregroundColor(.white)
                               .padding(.horizontal, 12)
                               .padding(.vertical, 6)
                               .background(Color.purple)
                               .cornerRadius(4)
                       }

                       // 2D/3D mode toggle (only available when 3D strokes exist)
                       if !strokes3D.isEmpty {
                           Button(action: {
                               withAnimation(.easeInOut(duration: 0.3)) {
                                   if !show3DPreview {
                                       // Switching to 3D: save current 2D strokes and hide them
                                       saved2DStrokes = strokes2D
                                       strokes2D.removeAll()
                                   } else {
                                       // Switching to 2D: restore saved strokes
                                       strokes2D = saved2DStrokes
                                       saved2DStrokes.removeAll()
                                   }
                                   show3DPreview.toggle()
                                   currentStroke = nil      // Clear any active stroke
                                   isDrawing = false
                                   viewRefreshID = UUID()   // Force view refresh
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
               .padding(.top, 50)      // Account for status bar

               Spacer()

               // MARK: - Bottom Controls Area
               VStack(spacing: 20) {
                   // MARK: - Audio Call Controls (only visible during active call)
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
                               // Mute/Unmute button
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
                              
                               // Hold/Resume button
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
                           }
                           .padding(.horizontal, 16)
                           .padding(.vertical, 8)
                           .background(Color.black.opacity(0.6))
                           .cornerRadius(15)
                       }
                   }
                  
                   // MARK: - Drawing Toolbar (only in 2D mode)
                   if showToolbar && !show3DPreview {
                       DrawingToolbar(
                           tool: $drawingTool,
                           onClear: clearDrawings,          // Clear all drawings
                           onClear2: clear2DDrawings,       // Clear only 2D drawings (currently disabled)
                           onToggleToolbar: { showToolbar.toggle() }
                       )
                   } else if !show3DPreview {
                       // Collapsed toolbar - show expand button
                       Button(action: { showToolbar.toggle() }) {
                           Image(systemName: "paintbrush.fill")
                               .font(.system(size: 30))
                               .foregroundColor(.white)
                               .frame(width: 70, height: 70)
                               .background(Circle().fill(Color.black.opacity(0.6)))
                       }
                   }
                  
                   // MARK: - Connection Status
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
           setupReceivers()                    // Set up WebSocket message handlers
           if !socketManager.isConnected {
               socketManager.connect(as: "aid")    // Connect as aid device
               DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                   audioSocketHandler.startAudioCall()    // Start audio call after connection
               }
           }
       }
       .onDisappear {
           disconnect()                        // Clean up when view disappears
       }
       .onReceive(fpsTimer) { _ in
           // Update FPS counter every second
           fps = Double(frameCount)
           frameCount = 0
       }
   }

   // MARK: - WebSocket Message Handlers
   
   /**
    * Sets up handlers for different types of incoming WebSocket messages
    */
   private func setupReceivers() {
       // Handle incoming video frames
       socketManager.onImageReceived = { image in
           DispatchQueue.main.async {
               // Only update current image if not showing AR feedback
               if self.feedbackImage == nil {
                   self.currentImage = image
               }
               self.frameCount += 1        // Increment for FPS calculation
           }
       }

       // Handle AR feedback overlay images
       socketManager.onFeedbackReceived = { image in
           DispatchQueue.main.async {
               self.feedbackImage = image
               self.frameCount += 1
           }
       }

       // Handle clear drawings command from remote
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

       // Handle incoming drawing messages (mainly for 3D rendering)
       socketManager.onDrawingReceived = { message in
           DispatchQueue.main.async {
               switch message.action {
               case .render3D:
                   // Received 3D anchored drawing data
                   if let stroke = message.stroke,
                      let anchorData = message.anchorData {
                       self.strokes3D[stroke.id] = (stroke, anchorData)
                       
                       // Auto-switch to 3D mode when first 3D stroke arrives
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

   /**
    * Sends a completed drawing stroke to the remote device via WebSocket
    * - Parameter stroke: The completed drawing stroke to send
    */
   private func sendDrawing(_ stroke: DrawingStroke) {
       let message = DrawingMessage(
           action: .add,              // Add action type
           drawingId: stroke.id,      // Unique stroke identifier
           stroke: stroke             // Stroke data (points, color, thickness)
       )
       socketManager.sendDrawingMessage(message)
       
       // Clear local 2D strokes after sending (they will be returned as 3D if anchored)
       strokes2D.removeAll()
       saved2DStrokes.removeAll()
       viewRefreshID = UUID()
   }

   /**
    * Clears all drawings locally and sends clear command to remote
    */
   private func clearDrawings() {
       strokes2D.removeAll()
       saved2DStrokes.removeAll()
       strokes3D.removeAll()
       currentStroke = nil
       isDrawing = false
       show3DPreview = false
       viewRefreshID = UUID()
       socketManager.sendClearDrawings()    // Notify remote to clear as well
   }
    
   /**
    * Placeholder function for clearing only 2D drawings
    * Currently disabled/commented out
    */
    private func clear2DDrawings() {
//        strokes2D.removeAll()
//        saved2DStrokes.removeAll()
//        viewRefreshID = UUID()
    }

   /**
    * Disconnects from audio and WebSocket, then dismisses the view
    */
   private func disconnect() {
       audioSocketHandler.endAudioCall()
       socketManager.disconnect()
       dismiss()
   }
}

// MARK: - Drawing Display Component

/**
 * DrawingView handles the visual display of both 2D and 3D drawings
 * Uses UIViewRepresentable to bridge UIKit views with SwiftUI
 */
struct DrawingView: UIViewRepresentable {
   let strokes2D: [DrawingStroke]                                     // 2D overlay strokes
   let strokes3D: [String: (DrawingStroke, Drawing3DAnchorData)]     // 3D anchored strokes
   let currentStroke: DrawingStroke?                                  // Currently active stroke
   let viewSize: CGSize                                               // View dimensions for scaling
   let show3D: Bool                                                   // Display mode toggle

   /**
    * Creates the underlying UIView structure with both 2D and 3D views
    */
   func makeUIView(context: Context) -> UIView {
       let containerView = UIView()
       containerView.backgroundColor = .clear

       // Create 2D drawing view (standard UIView with CAShapeLayer drawing)
       let view2D = UIView()
       view2D.backgroundColor = .clear
       containerView.addSubview(view2D)

       // Create 3D scene view (SceneKit for 3D rendering)
       let view3D = SCNView()
       view3D.backgroundColor = .clear
       view3D.scene = SCNScene()
       view3D.autoenablesDefaultLighting = false     // Custom lighting setup
       containerView.addSubview(view3D)

       // Set up Auto Layout constraints to fill container
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

       // MARK: - 3D Scene Setup
       
       // Configure camera for 3D scene
       let cameraNode = SCNNode()
       cameraNode.camera = SCNCamera()
       cameraNode.camera?.usesOrthographicProjection = false    // Perspective projection
       cameraNode.camera?.fieldOfView = 60                     // 60-degree field of view
       cameraNode.position = SCNVector3(0, 0.5, 2)            // Position camera above and back from origin
       cameraNode.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
       view3D.scene?.rootNode.addChildNode(cameraNode)

       // Set camera as active viewpoint and enable user interaction
       view3D.pointOfView = cameraNode
       view3D.allowsCameraControl = true                        // Allow user to orbit/zoom
       view3D.defaultCameraController.interactionMode = .orbitTurntable
       view3D.defaultCameraController.inertiaEnabled = true

       // Add main light source
       let lightNode = SCNNode()
       lightNode.light = SCNLight()
       lightNode.light?.type = .omni                           // Omnidirectional light
       lightNode.light?.intensity = 1500                      // High intensity
       lightNode.position = SCNVector3(0, 0, 2)               // Position with camera
       view3D.scene?.rootNode.addChildNode(lightNode)

       // Add ambient lighting for overall illumination
       let ambientLightNode = SCNNode()
       ambientLightNode.light = SCNLight()
       ambientLightNode.light?.type = .ambient
       ambientLightNode.light?.intensity = 500                // Softer ambient light
       view3D.scene?.rootNode.addChildNode(ambientLightNode)

       // Store references in coordinator for later access
       context.coordinator.view2D = view2D
       context.coordinator.view3D = view3D

       return containerView
   }

   /**
    * Updates the view content when data changes
    * Handles switching between 2D and 3D modes and rendering strokes
    */
   func updateUIView(_ containerView: UIView, context: Context) {
       guard let view2D = context.coordinator.view2D,
             let view3D = context.coordinator.view3D else { return }

       // Clear previous content
       view2D.layer.sublayers?.forEach { $0.removeFromSuperlayer() }    // Remove 2D stroke layers
       view3D.scene?.rootNode.childNodes
           .filter { $0.name == "stroke" }                              // Remove 3D stroke nodes
           .forEach { $0.removeFromParentNode() }

       // Render 2D strokes (including current active stroke)
       var all2DStrokes = strokes2D
       if let current = currentStroke {
           all2DStrokes.append(current)
       }

       for stroke in all2DStrokes {
           draw2DStroke(stroke, in: view2D)
       }

       // Render 3D strokes with their anchor transforms
       for (_, (stroke, anchorData)) in strokes3D {
           let strokeNode = create3DStroke(
               stroke: stroke,
               anchorTransform: anchorData.worldTransform.simdTransform,    // AR world transform
               distance: anchorData.distance                                 // Distance from camera
           )
           strokeNode.name = "stroke"                                       // Tag for easy removal
           view3D.scene?.rootNode.addChildNode(strokeNode)
       }

       // Show appropriate view based on mode
       if show3D {
           view2D.isHidden = true
           view3D.isHidden = false
       } else {
           view2D.isHidden = false
           view3D.isHidden = true
       }
   }

   /**
    * Creates coordinator to maintain references to child views
    */
   func makeCoordinator() -> Coordinator {
       Coordinator()
   }

   /**
    * Coordinator class holds references to the 2D and 3D views
    */
   class Coordinator {
       var view2D: UIView?
       var view3D: SCNView?
   }

   /**
    * Renders a 2D stroke as a CAShapeLayer path
    * - Parameter stroke: The drawing stroke to render
    * - Parameter view: The UIView to draw on
    */
   private func draw2DStroke(_ stroke: DrawingStroke, in view: UIView) {
       guard stroke.points.count > 1 else { return }

       // Create Bezier path from stroke points
       let path = UIBezierPath()
       let points = stroke.points.map { point in
           CGPoint(
               x: CGFloat(point.x) * view.bounds.width,     // Convert normalized coordinates to view coordinates
               y: CGFloat(point.y) * view.bounds.height
           )
       }

       // Draw connected line segments
       path.move(to: points[0])
       for i in 1..<points.count {
           path.addLine(to: points[i])
       }

       // Create shape layer with stroke properties
       let shapeLayer = CAShapeLayer()
       shapeLayer.path = path.cgPath
       shapeLayer.strokeColor = stroke.color.uiColor.cgColor
       shapeLayer.lineWidth = CGFloat(stroke.thickness * 1000)          // Scale thickness for visibility
       shapeLayer.fillColor = UIColor.clear.cgColor                    // No fill, stroke only
       shapeLayer.lineCap = .round                                     // Rounded line caps
       shapeLayer.lineJoin = .round                                    // Rounded joins

       view.layer.addSublayer(shapeLayer)
   }

   /**
    * Creates a 3D representation of a stroke using SceneKit nodes
    * - Parameter stroke: The drawing stroke data
    * - Parameter anchorTransform: AR world transform matrix
    * - Parameter distance: Distance from camera for scaling
    * - Returns: SCNNode containing the 3D stroke geometry
    */
   private func create3DStroke(stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
       let strokeNode = SCNNode()

       guard stroke.points.count > 1 else { return strokeNode }

       // Calculate scaling factors based on distance and stroke properties
       let scaleFactor = distance * 0.3                        // Scale based on distance
       let lineThickness = stroke.thickness * 0.5              // Scale thickness for 3D

       // Find bounding box of stroke for centering
       let minX = stroke.points.map { $0.x }.min() ?? 0
       let maxX = stroke.points.map { $0.x }.max() ?? 1
       let minY = stroke.points.map { $0.y }.min() ?? 0
       let maxY = stroke.points.map { $0.y }.max() ?? 1

       let centerX = (minX + maxX) / 2                          // Center point X
       let centerY = (minY + maxY) / 2                          // Center point Y

       let aspectRatio = Float(viewSize.width / viewSize.height)

       var points3D: [SCNVector3] = []

       // Convert 2D stroke points to 3D coordinates
       for point in stroke.points {
           let normalizedX = (point.x - centerX) * 2.0          // Center and normalize
           let normalizedY = -(point.y - centerY) * 2.0         // Flip Y (screen vs 3D coords)

           let scaledX = normalizedX * scaleFactor
           let scaledY = normalizedY * scaleFactor / aspectRatio    // Adjust for aspect ratio

           points3D.append(SCNVector3(x: scaledX, y: scaledY, z: 0))
       }

       // Apply smoothing to make stroke look more natural
       let smoothedPoints = smoothPath(points: points3D, iterations: 2)

       // Create cylinder segments between consecutive points
       for i in 0..<(smoothedPoints.count - 1) {
           let start = smoothedPoints[i]
           let end = smoothedPoints[i + 1]

           let cylinder = createCylinderBetween(
               start: start,
               end: end,
               radius: lineThickness * 0.3,                     // Cylinder radius
               color: stroke.color.uiColor
           )
           strokeNode.addChildNode(cylinder)
       }

       // Add spheres at key points for better visual continuity
       for (index, point) in smoothedPoints.enumerated() {
           if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
               let sphere = SCNSphere(radius: CGFloat(lineThickness * 0.5))
               sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
               sphere.firstMaterial?.lightingModel = .constant         // No lighting calculation
               sphere.firstMaterial?.emission.contents = stroke.color.uiColor
               sphere.firstMaterial?.emission.intensity = 0.2          // Slight glow effect

               let sphereNode = SCNNode(geometry: sphere)
               sphereNode.position = point
               strokeNode.addChildNode(sphereNode)
           }
       }

       // Apply AR anchor transform to position stroke in world space
       strokeNode.simdTransform = anchorTransform

       return strokeNode
   }

   /**
    * Smooths a path by averaging neighboring points
    * - Parameter points: Original 3D points
    * - Parameter iterations: Number of smoothing passes
    * - Returns: Smoothed 3D points
    */
   private func smoothPath(points: [SCNVector3], iterations: Int = 1) -> [SCNVector3] {
       guard points.count > 2 else { return points }

       var smoothed = points

       // Apply smoothing algorithm for specified iterations
       for _ in 0..<iterations {
           var newPoints: [SCNVector3] = []
           newPoints.append(smoothed[0])        // Keep first point unchanged

           // Smooth interior points using weighted average of neighbors
           for i in 1..<(smoothed.count - 1) {
               let prev = smoothed[i - 1]
               let curr = smoothed[i]
               let next = smoothed[i + 1]

               // Weighted average: 25% prev + 50% current + 25% next
               let smoothX = (prev.x + 2 * curr.x + next.x) / 4
               let smoothY = (prev.y + 2 * curr.y + next.y) / 4
               let smoothZ = (prev.z + 2 * curr.z + next.z) / 4

               newPoints.append(SCNVector3(x: smoothX, y: smoothY, z: smoothZ))
           }

           newPoints.append(smoothed.last!)     // Keep last point unchanged
           smoothed = newPoints
       }

       return smoothed
   }

   /**
    * Creates a cylinder between two 3D points to represent a stroke segment
    * - Parameter start: Starting 3D position
    * - Parameter end: Ending 3D position
    * - Parameter radius: Cylinder radius
    * - Parameter color: Stroke color
    * - Returns: SCNNode containing positioned and oriented cylinder
    */
   private func createCylinderBetween(start: SCNVector3, end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
       // Calculate distance between points
       let distance = simd_distance(
           simd_float3(start.x, start.y, start.z),
           simd_float3(end.x, end.y, end.z)
       )

       guard distance > 0 else { return SCNNode() }

       // Create cylinder geometry
       let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(distance))
       cylinder.radialSegmentCount = 16                     // Smooth circular cross-section

       // Configure material properties
       let material = SCNMaterial()
       material.diffuse.contents = color                    // Base color
       material.lightingModel = .constant                   // No lighting calculation for consistent appearance
       material.isDoubleSided = true                       // Visible from both sides
       material.emission.contents = color                   // Slight glow effect
       material.emission.intensity = 0.2
       material.shininess = 0.0                            // Matte finish

       cylinder.materials = [material]

       let cylinderNode = SCNNode(geometry: cylinder)

       // Position cylinder at midpoint between start and end
       cylinderNode.position = SCNVector3(
           x: (start.x + end.x) / 2,
           y: (start.y + end.y) / 2,
           z: (start.z + end.z) / 2
       )

       // Calculate direction vector and orient cylinder accordingly
       let direction = simd_normalize(
           simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
       )

       let up = simd_float3(0, 1, 0)                       // Default cylinder orientation (Y-axis)
       let dot = simd_dot(up, direction)

       // Handle special case where direction is parallel to Y-axis
       if abs(dot) > 0.999 {
           cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
       } else {
           // Calculate rotation axis and angle to align cylinder with direction
           let axis = simd_normalize(simd_cross(up, direction))
           let angle = acos(dot)
           cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
       }

       return cylinderNode
   }
}

// MARK: - Touch Input Overlay

/**
 * DrawingOverlay captures touch input and converts it to drawing strokes
 * Acts as a transparent layer over the video feed
 */
struct DrawingOverlay: UIViewRepresentable {
   @Binding var currentStroke: DrawingStroke?              // Currently active stroke
   @Binding var isDrawing: Bool                           // Drawing state flag
   let tool: DrawingTool                                  // Current drawing tool settings
   let onStrokeCompleted: (DrawingStroke) -> Void         // Callback when stroke is finished

   func makeUIView(context: Context) -> DrawingTouchView {
       let view = DrawingTouchView()
       view.backgroundColor = .clear                       // Transparent overlay
       view.delegate = context.coordinator                 // Set touch delegate
       return view
   }

   func updateUIView(_ uiView: DrawingTouchView, context: Context) {
       context.coordinator.tool = tool                     // Update tool settings
   }

   func makeCoordinator() -> Coordinator {
       Coordinator(
           currentStroke: $currentStroke,
           isDrawing: $isDrawing,
           tool: tool,
           onStrokeCompleted: onStrokeCompleted
       )
   }

   /**
    * Coordinator handles touch events and manages drawing state
    */
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

       /**
        * Called when user begins touching the screen
        * Creates a new stroke with current tool settings
        */
       func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
           isDrawing = true
           currentStroke = DrawingStroke(
               color: tool.color,              // Use current tool color
               thickness: tool.thickness       // Use current tool thickness
           )

           // Add first point with touch force (if available)
           let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
           currentStroke?.points.append(drawingPoint)
       }

       /**
        * Called as user moves finger while drawing
        * Adds points to the current stroke
        */
       func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat) {
           guard isDrawing else { return }

           // Add point to current stroke
           let drawingPoint = DrawingPoint(normalizedPoint: normalizedPoint, force: Float(force))
           currentStroke?.points.append(drawingPoint)
       }

       /**
        * Called when user lifts finger or touch is cancelled
        * Completes the current stroke
        */
       func drawingEnded() {
           guard let stroke = currentStroke, !stroke.points.isEmpty else { return }

           isDrawing = false
           onStrokeCompleted(stroke)                       // Send completed stroke
           currentStroke = nil                             // Clear current stroke
       }
   }
}

// MARK: - Touch Handling Protocols and Classes

/**
 * Protocol for handling drawing touch events
 */
protocol DrawingTouchViewDelegate: AnyObject {
   func drawingBegan(at point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
   func drawingMoved(to point: CGPoint, normalizedPoint: CGPoint, force: CGFloat)
   func drawingEnded()
}

/**
 * Custom UIView that captures touch events and converts them to normalized coordinates
 * Handles force touch when available (3D Touch/Haptic Touch)
 */
class DrawingTouchView: UIView {
   weak var delegate: DrawingTouchViewDelegate?

   /**
    * Touch began - start of drawing stroke
    */
   override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
       guard let touch = touches.first else { return }

       let point = touch.location(in: self)
       // Convert to normalized coordinates (0.0 to 1.0)
       let normalizedPoint = CGPoint(
           x: point.x / bounds.width,
           y: point.y / bounds.height
       )
       // Get touch force (1.0 if force touch not available)
       let force = touch.force > 0 ? touch.force / touch.maximumPossibleForce : 1.0

       delegate?.drawingBegan(at: point, normalizedPoint: normalizedPoint, force: force)
   }

   /**
    * Touch moved - continuation of drawing stroke
    */
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

   /**
    * Touch ended - end of drawing stroke
    */
   override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
       delegate?.drawingEnded()
   }

   /**
    * Touch cancelled - treat as end of stroke
    */
   override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
       delegate?.drawingEnded()
   }
}

// MARK: - Drawing Toolbar

/**
 * DrawingToolbar provides UI for selecting drawing colors, brush sizes, and actions
 */
struct DrawingToolbar: View {
   @Binding var tool: DrawingTool                          // Current drawing tool settings
   let onClear: () -> Void                                // Clear all drawings callback
   let onClear2: () -> Void                               // Clear 2D drawings callback (unused)
   let onToggleToolbar: () -> Void                        // Toggle toolbar visibility

   var body: some View {
       VStack(spacing: 12) {
           // MARK: - Color Selection Scrollable Row
           ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 12) {
                   ForEach(DrawingTool.colors, id: \.self) { color in
                       Button(action: { tool.color = color }) {
                           Circle()
                               .fill(Color(color))         // Color circle
                               .frame(width: 40, height: 40)
                               .overlay(
                                   Circle()
                                       // White border when selected
                                       .stroke(tool.color == color ? Color.white : Color.clear, lineWidth: 3)
                               )
                       }
                   }
               }
           }

           // MARK: - Brush Size and Controls
           VStack(spacing: 8) {
               Text("Brush Size")
                   .font(.caption)
                   .foregroundColor(.white.opacity(0.9))

               HStack(spacing: 16) {
                   // Brush size selection circles
                   ForEach(Array(DrawingTool.thicknesses.enumerated()), id: \.offset) { index, thickness in
                       VStack(spacing: 4) {
                           Button(action: { tool.thickness = thickness }) {
                               Circle()
                                   .fill(Color.white)
                                   // Size increases with index for visual feedback
                                   .frame(width: CGFloat(14 + index * 7), height: CGFloat(14 + index * 7))
                                   .opacity(tool.thickness == thickness ? 1.0 : 0.5)
                                   .overlay(
                                       Circle()
                                           // Blue border when selected
                                           .stroke(Color.blue, lineWidth: tool.thickness == thickness ? 2 : 0)
                                   )
                           }

                           // Labels for first and last sizes
                           Text(index == 0 ? "Near" : index == 3 ? "Far" : "")
                               .font(.system(size: 8))
                               .foregroundColor(.white.opacity(0.7))
                       }
                   }

                   Spacer()

                   // MARK: - Action Buttons
                   HStack(spacing: 12) {
                       // Clear all drawings button
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

                       // Collapse toolbar button
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
       .background(Color.black.opacity(0.8))              // Semi-transparent dark background
       .cornerRadius(20)
   }
}
