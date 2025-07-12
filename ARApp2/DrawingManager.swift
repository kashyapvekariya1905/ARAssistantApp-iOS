


import ARKit
import SceneKit

class DrawingManager: ObservableObject {
    private var arView: ARSCNView?
    private var activeDrawings: [String: SCNNode] = [:]
    
    @Published var isDrawingEnabled = true
    @Published var currentTool = DrawingTool()
    
    // Configure manager with AR view
    func configure(with arView: ARSCNView) {
        self.arView = arView
    }
    
    // MARK: - 3D Drawing Creation
    
    func createDrawing3D(from stroke: DrawingStroke, at normalizedPoint: CGPoint) -> Drawing3DAnchor? {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame else { return nil }
        
        // Convert normalized coordinates to screen coordinates
        let screenPoint = CGPoint(
            x: normalizedPoint.x * arView.bounds.width,
            y: normalizedPoint.y * arView.bounds.height
        )
        
        // Perform hit test to find surface
        let hitTestResults = arView.hitTest(screenPoint, types: [.featurePoint, .estimatedHorizontalPlane])
        
        guard let result = hitTestResults.first else {
            // If no hit test result, project at a default distance
            let transform = estimateTransform(at: screenPoint, distance: 0.5, in: arView)
            return Drawing3DAnchor(id: stroke.id, worldTransform: transform, stroke: stroke)
        }
        
        return Drawing3DAnchor(
            id: stroke.id,
            worldTransform: result.worldTransform,
            stroke: stroke
        )
    }
    
    // Create 3D line geometry from stroke points
    func createStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4) -> SCNNode {
        let strokeNode = SCNNode()
        
        guard stroke.points.count > 1 else { return strokeNode }
        
        // Convert 2D points to 3D positions
        let scale: Float = 0.3  // 30cm drawing area
        let points3D = stroke.points.map { point in
            return SCNVector3(
                x: (point.x - 0.5) * scale,
                y: 0,  // Keep on the plane
                z: (0.5 - point.y) * scale  // Invert Y to Z
            )
        }
        
        // Create tube segments between points
        for i in 0..<(points3D.count - 1) {
            let start = points3D[i]
            let end = points3D[i + 1]
            
            // Create a tube segment
            let segment = createTubeSegment(
                from: start,
                to: end,
                radius: CGFloat(stroke.thickness),
                color: stroke.color.uiColor
            )
            
            strokeNode.addChildNode(segment)
        }
        
        // Add spheres at joints for smooth connections
        for point in points3D {
            let sphere = SCNSphere(radius: CGFloat(stroke.thickness))
            sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
            sphere.firstMaterial?.lightingModel = .constant
            
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = point
            strokeNode.addChildNode(sphereNode)
        }
        
        // Apply world transform
        strokeNode.simdTransform = anchorTransform
        
        return strokeNode
    }
    
    // Create a cylindrical tube segment between two points
    private func createTubeSegment(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
        let distance = simd_distance(
            simd_float3(start.x, start.y, start.z),
            simd_float3(end.x, end.y, end.z)
        )
        
        // Create cylinder
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel = .constant
        
        let cylinderNode = SCNNode(geometry: cylinder)
        
        // Position at midpoint
        cylinderNode.position = SCNVector3(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2,
            z: (start.z + end.z) / 2
        )
        
        // Orient cylinder to connect the points
        let direction = simd_normalize(
            simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
        )
        
        let up = simd_float3(0, 1, 0)
        let dot = simd_dot(up, direction)
        
        if abs(dot) > 0.999 {
            // Direction is parallel to up vector, use different approach
            cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
        } else {
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(dot)
            cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        
        return cylinderNode
    }
    
    // MARK: - Alternative Smooth Line Implementation
    
    func createSmoothStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4) -> SCNNode {
        let strokeNode = SCNNode()
        
        guard stroke.points.count > 1 else { return strokeNode }
        
        // Convert points and create smooth path
        let scale: Float = 0.3
        let points3D = stroke.points.map { point in
            return SCNVector3(
                x: (point.x - 0.5) * scale,
                y: 0,
                z: (0.5 - point.y) * scale
            )
        }
        
        // Generate smooth curve points using Catmull-Rom interpolation
        let smoothPoints = generateSmoothCurve(from: points3D, segments: 10)
        
        // Create geometry from smooth points
        if let lineGeometry = createLineGeometry(
            points: smoothPoints,
            radius: stroke.thickness,
            color: stroke.color.uiColor
        ) {
            let lineNode = SCNNode(geometry: lineGeometry)
            strokeNode.addChildNode(lineNode)
        }
        
        strokeNode.simdTransform = anchorTransform
        return strokeNode
    }
    
    // Generate smooth curve using Catmull-Rom spline
    private func generateSmoothCurve(from points: [SCNVector3], segments: Int) -> [SCNVector3] {
        guard points.count > 2 else { return points }
        
        var smoothPoints: [SCNVector3] = []
        
        for i in 0..<(points.count - 1) {
            let p0 = i > 0 ? points[i - 1] : points[i]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = i < points.count - 2 ? points[i + 2] : points[i + 1]
            
            for j in 0..<segments {
                let t = Float(j) / Float(segments)
                let point = catmullRomInterpolate(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
                smoothPoints.append(point)
            }
        }
        
        smoothPoints.append(points.last!)
        return smoothPoints
    }
    
    // Catmull-Rom interpolation
    private func catmullRomInterpolate(p0: SCNVector3, p1: SCNVector3, p2: SCNVector3, p3: SCNVector3, t: Float) -> SCNVector3 {
        let t2 = t * t
        let t3 = t2 * t
        
        let v0 = SCNVector3(
            x: (p2.x - p0.x) * 0.5,
            y: (p2.y - p0.y) * 0.5,
            z: (p2.z - p0.z) * 0.5
        )
        
        let v1 = SCNVector3(
            x: (p3.x - p1.x) * 0.5,
            y: (p3.y - p1.y) * 0.5,
            z: (p3.z - p1.z) * 0.5
        )
        
        let a = SCNVector3(
            x: 2 * p1.x - 2 * p2.x + v0.x + v1.x,
            y: 2 * p1.y - 2 * p2.y + v0.y + v1.y,
            z: 2 * p1.z - 2 * p2.z + v0.z + v1.z
        )
        
        let b = SCNVector3(
            x: -3 * p1.x + 3 * p2.x - 2 * v0.x - v1.x,
            y: -3 * p1.y + 3 * p2.y - 2 * v0.y - v1.y,
            z: -3 * p1.z + 3 * p2.z - 2 * v0.z - v1.z
        )
        
        return SCNVector3(
            x: a.x * t3 + b.x * t2 + v0.x * t + p1.x,
            y: a.y * t3 + b.y * t2 + v0.y * t + p1.y,
            z: a.z * t3 + b.z * t2 + v0.z * t + p1.z
        )
    }
    
    // Create custom line geometry
    private func createLineGeometry(points: [SCNVector3], radius: Float, color: UIColor) -> SCNGeometry? {
        guard points.count > 1 else { return nil }
        
        // Create vertices for a tube mesh
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        
        let sides = 8  // Number of sides for the tube
        
        for i in 0..<points.count {
            let point = points[i]
            
            // Calculate direction
            let direction: SCNVector3
            if i == 0 {
                direction = simd_normalize(simd_float3(
                    points[i + 1].x - point.x,
                    points[i + 1].y - point.y,
                    points[i + 1].z - point.z
                )).scnVector3
            } else if i == points.count - 1 {
                direction = simd_normalize(simd_float3(
                    point.x - points[i - 1].x,
                    point.y - points[i - 1].y,
                    point.z - points[i - 1].z
                )).scnVector3
            } else {
                direction = simd_normalize(simd_float3(
                    points[i + 1].x - points[i - 1].x,
                    points[i + 1].y - points[i - 1].y,
                    points[i + 1].z - points[i - 1].z
                )).scnVector3
            }
            
            // Create ring of vertices
            for j in 0..<sides {
                let angle = Float(j) * 2.0 * Float.pi / Float(sides)
                let x = cos(angle) * radius
                let z = sin(angle) * radius
                
                // Transform to align with direction
                let vertex = SCNVector3(x, 0, z)
                vertices.append(SCNVector3(
                    x: point.x + vertex.x,
                    y: point.y + vertex.y,
                    z: point.z + vertex.z
                ))
                
                normals.append(simd_normalize(simd_float3(x, 0, z)).scnVector3)
            }
        }
        
        // Create indices for triangle mesh
        for i in 0..<(points.count - 1) {
            for j in 0..<sides {
                let nextJ = (j + 1) % sides
                
                let a = Int32(i * sides + j)
                let b = Int32(i * sides + nextJ)
                let c = Int32((i + 1) * sides + j)
                let d = Int32((i + 1) * sides + nextJ)
                
                // Two triangles per quad
                indices.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        
        // Create geometry sources
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        
        // Create geometry element
        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .triangles
        )
        
        // Create geometry
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.isDoubleSided = true
        
        return geometry
    }
    
    // MARK: - Drawing Management
    
    func addDrawing(_ anchor: Drawing3DAnchor) {
        guard let arView = arView else { return }
        
        // Use the smooth stroke implementation for better curves
        let strokeNode = createSmoothStrokeNode(from: anchor.stroke, anchorTransform: anchor.worldTransform)
        activeDrawings[anchor.id] = strokeNode
        arView.scene.rootNode.addChildNode(strokeNode)
    }
    
    func updateDrawing(_ anchor: Drawing3DAnchor) {
        removeDrawing(withId: anchor.id)
        addDrawing(anchor)
    }
    
    func removeDrawing(withId id: String) {
        activeDrawings[id]?.removeFromParentNode()
        activeDrawings.removeValue(forKey: id)
    }
    
    func clearAllDrawings() {
        activeDrawings.values.forEach { $0.removeFromParentNode() }
        activeDrawings.removeAll()
    }
    
    // MARK: - Helper Methods
    
    private func estimateTransform(at screenPoint: CGPoint, distance: Float, in arView: ARSCNView) -> simd_float4x4 {
        guard let currentFrame = arView.session.currentFrame else {
            return matrix_identity_float4x4
        }
        
        // Get camera transform
        let cameraTransform = currentFrame.camera.transform
        
        // Convert screen point to normalized device coordinates
        let ndcX = (2.0 * Float(screenPoint.x) / Float(arView.bounds.width)) - 1.0
        let ndcY = 1.0 - (2.0 * Float(screenPoint.y) / Float(arView.bounds.height))
        
        // Create ray from camera through screen point
        let ndcPoint = simd_float4(ndcX, ndcY, 1.0, 1.0)
        let clipToCamera = simd_inverse(currentFrame.camera.projectionMatrix)
        let cameraPoint = clipToCamera * ndcPoint
        
        let rayDirection = simd_normalize(simd_make_float3(cameraPoint.x, cameraPoint.y, -cameraPoint.z))
        let worldDirection = simd_mul(simd_float3x3(cameraTransform[0].xyz,
                                                     cameraTransform[1].xyz,
                                                     cameraTransform[2].xyz), rayDirection)
        
        // Calculate position at distance
        let cameraPosition = simd_make_float3(cameraTransform[3])
        let worldPosition = cameraPosition + worldDirection * distance
        
        // Create transform matrix
        var transform = matrix_identity_float4x4
        transform[3] = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        
        return transform
    }
}

// SIMD extensions
extension simd_float4 {
    var xyz: simd_float3 {
        simd_float3(x, y, z)
    }
}

extension simd_float3 {
    var scnVector3: SCNVector3 {
        SCNVector3(x, y, z)
    }
}
