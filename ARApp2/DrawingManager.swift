
import ARKit
import SceneKit

class DrawingManager: ObservableObject {
    private var arView: ARSCNView?
    private var activeDrawings: [String: SCNNode] = [:]
    private var drawingNodes: [String: [SCNNode]] = [:]
    
    @Published var isDrawingEnabled = true
    @Published var currentTool = DrawingTool()
    
    func configure(with arView: ARSCNView) {
        self.arView = arView
    }
    
    func getARView() -> ARSCNView? {
        return arView
    }
    
    func processIncomingStroke(_ stroke: DrawingStroke) {
        guard let arView = arView else { return }
        
        removeDrawing(withId: stroke.id)
        
        var strokeNodes: [SCNNode] = []
        var worldPositions: [SCNVector3] = []
        
        for (index, point) in stroke.points.enumerated() {
            let screenPoint = CGPoint(
                x: CGFloat(point.x) * arView.bounds.width,
                y: CGFloat(point.y) * arView.bounds.height
            )
            
            let hitTestResults = arView.hitTest(screenPoint, types: [
                .existingPlaneUsingExtent,
                .existingPlaneUsingGeometry,
                .estimatedHorizontalPlane,
                .estimatedVerticalPlane,
                .featurePoint
            ])
            
            if let hitResult = hitTestResults.first {
                let transform = hitResult.worldTransform
                let position = SCNVector3(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )
                
                worldPositions.append(position)
                
                let sphereRadius = CGFloat(stroke.thickness * 0.5)
                let sphereGeometry = SCNSphere(radius: sphereRadius)
                
                let material = SCNMaterial()
                material.diffuse.contents = stroke.color.uiColor
                material.emission.contents = stroke.color.uiColor
                material.emission.intensity = 0.2
                material.lightingModel = .constant
                
                sphereGeometry.materials = [material]
                
                let sphereNode = SCNNode(geometry: sphereGeometry)
                sphereNode.position = position
                sphereNode.name = "stroke_\(stroke.id)_\(index)"
                
                arView.scene.rootNode.addChildNode(sphereNode)
                strokeNodes.append(sphereNode)
                
                if index > 0 && index < stroke.points.count && worldPositions.count > 1 {
                    let previousPosition = worldPositions[worldPositions.count - 2]
                    let lineNode = createLineBetween(
                        start: previousPosition,
                        end: position,
                        color: stroke.color.uiColor,
                        thickness: CGFloat(stroke.thickness * 0.3)
                    )
                    lineNode.name = "stroke_line_\(stroke.id)_\(index)"
                    arView.scene.rootNode.addChildNode(lineNode)
                    strokeNodes.append(lineNode)
                }
            }
        }
        
        drawingNodes[stroke.id] = strokeNodes
        
        if !worldPositions.isEmpty {
            let centerX = worldPositions.reduce(0) { $0 + $1.x } / Float(worldPositions.count)
            let centerY = worldPositions.reduce(0) { $0 + $1.y } / Float(worldPositions.count)
            let centerZ = worldPositions.reduce(0) { $0 + $1.z } / Float(worldPositions.count)
            
            let centerPosition = simd_float3(centerX, centerY, centerZ)
            
            var transform = matrix_identity_float4x4
            transform.columns.3 = simd_float4(centerPosition, 1.0)
            
            let distance = simd_distance(centerPosition, arView.pointOfView?.simdPosition ?? simd_float3(0, 0, 0))

            
            let anchorData = Drawing3DAnchorData(
                worldTransform: transform,
                distance: distance
            )
            
            let render3DMessage = DrawingMessage(
                action: .render3D,
                drawingId: stroke.id,
                stroke: stroke,
                anchorData: anchorData
            )
            SocketManager.shared.sendDrawingMessage(render3DMessage)
        }
    }
    
    private func createLineBetween(start: SCNVector3, end: SCNVector3, color: UIColor, thickness: CGFloat) -> SCNNode {
        let distance = simd_distance(
            simd_float3(start.x, start.y, start.z),
            simd_float3(end.x, end.y, end.z)
        )
        
        guard distance > 0 else {
            return SCNNode()
        }
        
        let cylinder = SCNCylinder(radius: thickness, height: CGFloat(distance))
        cylinder.radialSegmentCount = 8
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 0.2
        material.lightingModel = .constant
        
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
    
    func removeDrawing(withId id: String) {
        if let nodes = drawingNodes[id] {
            nodes.forEach { $0.removeFromParentNode() }
            drawingNodes.removeValue(forKey: id)
        }
        
        arView?.scene.rootNode.childNodes.forEach { node in
            if let name = node.name,
               (name.hasPrefix("stroke_\(id)") || name.hasPrefix("stroke_line_\(id)")) {
                node.removeFromParentNode()
            }
        }
    }
    
    func clearAllDrawings() {
        drawingNodes.values.forEach { nodes in
            nodes.forEach { $0.removeFromParentNode() }
        }
        drawingNodes.removeAll()
        
        arView?.scene.rootNode.childNodes.forEach { node in
            if let name = node.name,
               (name.hasPrefix("stroke_") || name.hasPrefix("stroke_line_")) {
                node.removeFromParentNode()
            }
        }
    }
}

struct Drawing3DAnchor {
    let id: String
    let worldTransform: simd_float4x4
    let stroke: DrawingStroke
    let distance: Float
}

