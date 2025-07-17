
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
    
    // MARK: - 3D Drawing Creation with Enhanced Object Detection
    
    func createDrawing3D(from stroke: DrawingStroke, at normalizedPoint: CGPoint) -> Drawing3DAnchor? {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame else { return nil }
        
        // Get all points for better surface detection
        let screenPoints = stroke.points.map { point in
            CGPoint(
                x: CGFloat(point.x) * arView.bounds.width,
                y: CGFloat(point.y) * arView.bounds.height
            )
        }
        
        // Try multiple points to find the best surface
        var bestHitResult: ARHitTestResult?
        var bestDistance: Float = Float.infinity
        
        // Sample points along the stroke for better detection
        let sampleCount = min(5, screenPoints.count)
        let step = max(1, screenPoints.count / sampleCount)
        
        for i in stride(from: 0, to: screenPoints.count, by: step) {
            let point = screenPoints[i]
            
            // Comprehensive hit test with all available methods
            let hitResults = arView.hitTest(point, types: [
                .existingPlaneUsingGeometry,
                .existingPlaneUsingExtent,
                .estimatedHorizontalPlane,
                .estimatedVerticalPlane,
                .featurePoint
            ])
            
            if let result = hitResults.first {
                let hitPos = result.worldTransform.columns.3
                let cameraPos = currentFrame.camera.transform.columns.3
                let distance = simd_distance(
                    simd_float3(cameraPos.x, cameraPos.y, cameraPos.z),
                    simd_float3(hitPos.x, hitPos.y, hitPos.z)
                )
                
                if distance < bestDistance {
                    bestDistance = distance
                    bestHitResult = result
                }
            }
        }
        
        // Use raycast as fallback for better accuracy
        if bestHitResult == nil {
            let centerPoint = screenPoints[screenPoints.count / 2]
            
            // Try raycast for more accurate surface detection
            if let query = arView.raycastQuery(
                from: centerPoint,
                allowing: .estimatedPlane,
                alignment: .any
            ) {
                let results = arView.session.raycast(query)
                if let raycastResult = results.first {
                    let cameraPosition = simd_float3(currentFrame.camera.transform.columns.3.x,
                                                     currentFrame.camera.transform.columns.3.y,
                                                     currentFrame.camera.transform.columns.3.z)

                    let hitPosition = simd_float3(raycastResult.worldTransform.columns.3.x,
                                                  raycastResult.worldTransform.columns.3.y,
                                                  raycastResult.worldTransform.columns.3.z)

                    let distance = simd_distance(cameraPosition, hitPosition)

                    
                    return Drawing3DAnchor(
                        id: stroke.id,
                        worldTransform: raycastResult.worldTransform,
                        stroke: stroke,
                        distance: distance
                    )
                }
            }
            
            // Final fallback with smart distance estimation
            let estimatedDistance = estimateDistanceFromContext(screenPoints: screenPoints, in: arView)
            let transform = createTransformOnVirtualPlane(
                at: centerPoint,
                distance: estimatedDistance,
                in: arView
            )
            
            return Drawing3DAnchor(
                id: stroke.id,
                worldTransform: transform,
                stroke: stroke,
                distance: estimatedDistance
            )
        }
        
        return Drawing3DAnchor(
            id: stroke.id,
            worldTransform: bestHitResult!.worldTransform,
            stroke: stroke,
            distance: bestDistance
        )
    }
    
    // Create 3D stroke with proper object-relative positioning
    func createStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
        let strokeNode = SCNNode()
        
        guard stroke.points.count > 1 else { return strokeNode }
        
        // Dynamic scaling based on distance
        let minScale: Float = 0.05
        let maxScale: Float = 2.0
        let distanceFactor = min(max(distance * 0.15, minScale), maxScale)
        let scale = distanceFactor
        
        // Adaptive thickness that's visible at all distances
        let baseThickness = stroke.thickness
        let minThickness: Float = 0.002
        let thicknessScale = max(distance * 0.3, 1.0)
        let adaptiveThickness = max(baseThickness * thicknessScale, minThickness)
        
        // Convert 2D points to 3D with proper perspective
        let points3D = convertTo3DWithPerspective(
            points2D: stroke.points,
            scale: scale,
            anchorTransform: anchorTransform
        )
        
        // Create smooth path with adaptive detail
        let segmentCount = distance > 5 ? 5 : 10
        let smoothPoints = generateSmoothCurve(from: points3D, segments: segmentCount)
        
        // Build the stroke geometry
        for i in 0..<(smoothPoints.count - 1) {
            let start = smoothPoints[i]
            let end = smoothPoints[i + 1]
            
            let segment = createTubeSegment(
                from: start,
                to: end,
                radius: CGFloat(adaptiveThickness),
                color: stroke.color.uiColor
            )
            
            strokeNode.addChildNode(segment)
        }
        
        // Add end caps for better visibility
        for (index, point) in smoothPoints.enumerated() {
            if index == 0 || index == smoothPoints.count - 1 {
                let sphere = SCNSphere(radius: CGFloat(adaptiveThickness * 1.2))
                sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
                sphere.firstMaterial?.lightingModel = .constant
                sphere.firstMaterial?.emission.contents = stroke.color.uiColor
                sphere.firstMaterial?.emission.intensity = 0.3
                
                let sphereNode = SCNNode(geometry: sphere)
                sphereNode.position = point
                strokeNode.addChildNode(sphereNode)
            }
        }
        
        // Apply transform
        strokeNode.simdTransform = anchorTransform
        
        // Add billboard constraint for better visibility at distance
        if distance > 5 {
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = [.Y]  // Allow rotation around Y axis only
            strokeNode.constraints = [constraint]
        }
        
        return strokeNode
    }
    
    // Convert 2D points to 3D with perspective correction
    private func convertTo3DWithPerspective(
        points2D: [DrawingPoint],
        scale: Float,
        anchorTransform: simd_float4x4
    ) -> [SCNVector3] {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame else {
            // Fallback conversion
            return points2D.map { point in
                SCNVector3(
                    x: (point.x - 0.5) * scale,
                    y: 0,
                    z: (0.5 - point.y) * scale
                )
            }
        }
        
        var points3D: [SCNVector3] = []
        let cameraTransform = currentFrame.camera.transform
//        let anchorPosition = simd_float3(anchorTransform.columns.3)
        let anchorPosition = simd_float3(anchorTransform.columns.3.x,
                                         anchorTransform.columns.3.y,
                                         anchorTransform.columns.3.z)
        
        for point in points2D {
            // Convert to screen coordinates
            let screenX = CGFloat(point.x) * arView.bounds.width
            let screenY = CGFloat(point.y) * arView.bounds.height
            
            // Perform hit test at this point
            let hitResults = arView.hitTest(
                CGPoint(x: screenX, y: screenY),
                types: [.featurePoint, .estimatedHorizontalPlane, .estimatedVerticalPlane]
            )
            
            if let hit = hitResults.first {
                // Use actual hit position relative to anchor
//                let hitPosition = simd_float3(hit.worldTransform.columns.3)
                
                let hitPosition = simd_float3(hit.worldTransform.columns.3.x,
                                              hit.worldTransform.columns.3.y,
                                              hit.worldTransform.columns.3.z)
                let relativePosition = hitPosition - anchorPosition
                
                points3D.append(SCNVector3(
                    x: relativePosition.x,
                    y: relativePosition.y,
                    z: relativePosition.z
                ))
            } else {
                // Fallback: project onto plane at anchor position
                let relativeX = (point.x - points2D[0].x) * scale
                let relativeY = (points2D[0].y - point.y) * scale
                
                points3D.append(SCNVector3(x: relativeX, y: 0, z: relativeY))
            }
        }
        
        return points3D
    }
    
    // Create cylindrical tube segment
    private func createTubeSegment(from start: SCNVector3, to end: SCNVector3, radius: CGFloat, color: UIColor) -> SCNNode {
        let distance = simd_distance(
            simd_float3(start.x, start.y, start.z),
            simd_float3(end.x, end.y, end.z)
        )
        
        guard distance > 0 else { return SCNNode() }
        
        let cylinder = SCNCylinder(radius: radius, height: CGFloat(distance))
        cylinder.radialSegmentCount = 8
        
        // Enhanced material for better visibility
        cylinder.firstMaterial?.diffuse.contents = color
        cylinder.firstMaterial?.lightingModel = .constant
        cylinder.firstMaterial?.emission.contents = color
        cylinder.firstMaterial?.emission.intensity = 0.2
        cylinder.firstMaterial?.isDoubleSided = true
        
        let cylinderNode = SCNNode(geometry: cylinder)
        
        // Position at midpoint
        cylinderNode.position = SCNVector3(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2,
            z: (start.z + end.z) / 2
        )
        
        // Orient cylinder
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
    
    // Generate smooth curve
    private func generateSmoothCurve(from points: [SCNVector3], segments: Int) -> [SCNVector3] {
        guard points.count > 2 else { return points }
        
        var smoothPoints: [SCNVector3] = []
        
        // Use Catmull-Rom spline for smooth interpolation
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
    
    // MARK: - Drawing Management
    
    func addDrawing(_ anchor: Drawing3DAnchor) {
        guard let arView = arView else { return }
        
        let strokeNode = createStrokeNode(
            from: anchor.stroke,
            anchorTransform: anchor.worldTransform,
            distance: anchor.distance
        )
        
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
    
    private func estimateDistanceFromContext(screenPoints: [CGPoint], in arView: ARSCNView) -> Float {
        // Analyze the drawing size and position to estimate distance
        guard !screenPoints.isEmpty else { return 1.0 }
        
        let minX = screenPoints.map { $0.x }.min() ?? 0
        let maxX = screenPoints.map { $0.x }.max() ?? 0
        let minY = screenPoints.map { $0.y }.min() ?? 0
        let maxY = screenPoints.map { $0.y }.max() ?? 0
        
        let width = maxX - minX
        let height = maxY - minY
        let drawingSize = max(width, height)
        
        // Larger drawings typically indicate closer objects
        let screenSize = max(arView.bounds.width, arView.bounds.height)
        let sizeRatio = drawingSize / screenSize
        
        // Estimate distance based on drawing size
        if sizeRatio > 0.3 {
            return 0.5  // Close object
        } else if sizeRatio > 0.1 {
            return 2.0  // Medium distance
        } else {
            return 5.0  // Far object
        }
    }
    
    private func createTransformOnVirtualPlane(at screenPoint: CGPoint, distance: Float, in arView: ARSCNView) -> simd_float4x4 {
        guard let currentFrame = arView.session.currentFrame else {
            return matrix_identity_float4x4
        }
        
        let cameraTransform = currentFrame.camera.transform
        
        // Convert to NDC
        let ndcX = (2.0 * Float(screenPoint.x) / Float(arView.bounds.width)) - 1.0
        let ndcY = 1.0 - (2.0 * Float(screenPoint.y) / Float(arView.bounds.height))
        
        // Create ray
        let ndcPoint = simd_float4(ndcX, ndcY, 1.0, 1.0)
        let clipToCamera = simd_inverse(currentFrame.camera.projectionMatrix)
        let cameraPoint = clipToCamera * ndcPoint
        
        let rayDirection = simd_normalize(simd_make_float3(cameraPoint.x, cameraPoint.y, -cameraPoint.z))
        let worldDirection = simd_mul(simd_float3x3(
            cameraTransform[0].xyz,
            cameraTransform[1].xyz,
            cameraTransform[2].xyz
        ), rayDirection)
        
        // Calculate position
        let cameraPosition = simd_make_float3(cameraTransform[3])
        let worldPosition = cameraPosition + worldDirection * distance
        
        // Create transform with proper orientation
        var transform = matrix_identity_float4x4
        
        // Set position
        transform[3] = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        
        // Align with camera facing direction for better visibility
        let forward = -worldDirection
        let right = simd_normalize(simd_cross(simd_float3(0, 1, 0), forward))
        let up = simd_normalize(simd_cross(forward, right))
        
        transform[0] = simd_float4(right.x, right.y, right.z, 0)
        transform[1] = simd_float4(up.x, up.y, up.z, 0)
        transform[2] = simd_float4(forward.x, forward.y, forward.z, 0)
        
        return transform
    }
}

// Drawing anchor with distance
struct Drawing3DAnchor {
    let id: String
    let worldTransform: simd_float4x4
    let stroke: DrawingStroke
    let distance: Float
    
    init(id: String, worldTransform: simd_float4x4, stroke: DrawingStroke, distance: Float = 1.0) {
        self.id = id
        self.worldTransform = worldTransform
        self.stroke = stroke
        self.distance = distance
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























