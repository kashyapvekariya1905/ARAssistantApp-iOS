
import SwiftUI

struct AidDrawingView: View {
    @StateObject private var socketManager = SocketManager.shared
    @State private var currentImage: UIImage?
    @State private var frameCount = 0
    @State private var fps: Double = 0
    @State private var currentStroke: DrawingStroke?
    @State private var isDrawing = false
    @State private var drawingTool = DrawingTool()
    @State private var showToolbar = true
    @State private var completedStrokes: [DrawingStroke] = []
    @Environment(\.dismiss) private var dismiss
    
    private let fpsTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Video feed
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
            
            // Drawing preview layer - shows completed strokes
            DrawingPreviewView(strokes: completedStrokes)
                .allowsHitTesting(false)
            
            // Current stroke preview
            if let stroke = currentStroke, isDrawing {
                DrawingPreviewView(strokes: [stroke])
                    .allowsHitTesting(false)
            }
            
            // Drawing overlay for input
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
            
            // UI Overlay
            VStack {
                // Top bar
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
                    
                    VStack(alignment: .trailing) {
                        Text(socketManager.connectionStatus)
                            .font(.caption)
                        if fps > 0 {
                            Text("\(Int(fps)) FPS")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
                
                // Drawing toolbar
                if showToolbar {
                    DrawingToolbar(
                        tool: $drawingTool,
                        onClear: clearDrawings,
                        onToggleToolbar: { showToolbar.toggle() }
                    )
                    .padding()
                }
            }
            
            // Toolbar toggle button when hidden
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
        socketManager.disconnect()
        dismiss()
    }
}

// Drawing preview view - shows strokes as 2D overlays
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
                    
                    if points.count == 2 {
                        path.addLine(to: points[1])
                    } else {
                        for i in 1..<points.count {
                            let current = points[i]
                            let previous = points[i-1]
                            
                            if i == 1 {
                                path.addLine(to: current)
                            } else {
                                let control = CGPoint(
                                    x: (previous.x + current.x) / 2,
                                    y: (previous.y + current.y) / 2
                                )
                                path.addQuadCurve(to: control, control: previous)
                                
                                if i == points.count - 1 {
                                    path.addLine(to: current)
                                }
                            }
                        }
                    }
                }
                .stroke(Color(stroke.color.uiColor), lineWidth: CGFloat(stroke.thickness * 100))
                .opacity(0.8)
            }
        }
    }
}

// Drawing overlay view for capturing touch input
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

// Touch handling view
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

// Drawing toolbar
struct DrawingToolbar: View {
    @Binding var tool: DrawingTool
    let onClear: () -> Void
    let onToggleToolbar: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Color picker
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
            
            // Thickness picker
            HStack(spacing: 16) {
                ForEach(Array(DrawingTool.thicknesses.enumerated()), id: \.offset) { index, thickness in
                    Button(action: { tool.thickness = thickness }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: CGFloat(10 + index * 5), height: CGFloat(10 + index * 5))
                            .opacity(tool.thickness == thickness ? 1.0 : 0.5)
                    }
                }
                
                Spacer()
                
                // Action buttons
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
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
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
}
















