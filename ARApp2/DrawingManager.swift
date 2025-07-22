
// too big drawing

//import ARKit
//import SceneKit
//
//class DrawingManager: ObservableObject {
//    private var arView: ARSCNView?
//    private var activeDrawings: [String: SCNNode] = [:]
//    
//    @Published var isDrawingEnabled = true
//    @Published var currentTool = DrawingTool()
//    
//    func configure(with arView: ARSCNView) {
//        self.arView = arView
//    }
//    
//    func createDrawing3D(from stroke: DrawingStroke, at normalizedPoint: CGPoint) -> Drawing3DAnchor? {
//        guard let arView = arView,
//              let currentFrame = arView.session.currentFrame else { return nil }
//        
//        let screenPoints = stroke.points.map { point in
//            CGPoint(
//                x: CGFloat(point.x) * arView.bounds.width,
//                y: CGFloat(point.y) * arView.bounds.height
//            )
//        }
//        
//        var sumX: CGFloat = 0
//        var sumY: CGFloat = 0
//        for point in screenPoints {
//            sumX += point.x
//            sumY += point.y
//        }
//        let centerPoint = CGPoint(x: sumX / CGFloat(screenPoints.count), y: sumY / CGFloat(screenPoints.count))
//        
//        var hitDistance: Float = 2.0
//        var worldTransform = matrix_identity_float4x4
//        var foundHit = false
//        
//        let hitResults = arView.hitTest(centerPoint, types: [
//            .existingPlaneUsingGeometry,
//            .existingPlaneUsingExtent,
//            .estimatedHorizontalPlane,
//            .estimatedVerticalPlane,
//            .featurePoint
//        ])
//        
//        if let result = hitResults.first {
//            worldTransform = result.worldTransform
//            let hitPos = result.worldTransform.columns.3
//            let cameraPos = currentFrame.camera.transform.columns.3
//            hitDistance = simd_distance(
//                simd_float3(cameraPos.x, cameraPos.y, cameraPos.z),
//                simd_float3(hitPos.x, hitPos.y, hitPos.z)
//            )
//            foundHit = true
//        }
//        
//        if !foundHit {
//            if let query = arView.raycastQuery(
//                from: centerPoint,
//                allowing: .estimatedPlane,
//                alignment: .any
//            ) {
//                let results = arView.session.raycast(query)
//                if let raycastResult = results.first {
//                    worldTransform = raycastResult.worldTransform
//                    let cameraPosition = simd_float3(currentFrame.camera.transform.columns.3.x,
//                                                   currentFrame.camera.transform.columns.3.y,
//                                                   currentFrame.camera.transform.columns.3.z)
//                    
//                    let hitPosition = simd_float3(raycastResult.worldTransform.columns.3.x,
//                                                raycastResult.worldTransform.columns.3.y,
//                                                raycastResult.worldTransform.columns.3.z)
//                    
//                    hitDistance = simd_distance(cameraPosition, hitPosition)
//                    foundHit = true
//                }
//            }
//        }
//        
//        if !foundHit {
//            worldTransform = createAccurateTransform(
//                from: centerPoint,
//                distance: hitDistance,
//                in: arView,
//                currentFrame: currentFrame
//            )
//        }
//        
//        return Drawing3DAnchor(
//            id: stroke.id,
//            worldTransform: worldTransform,
//            stroke: stroke,
//            distance: hitDistance
//        )
//    }
//    
//    func createStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
//        let strokeNode = SCNNode()
//        
//        guard stroke.points.count > 1,
//              let arView = arView else { return strokeNode }
//        
//        let scaleFactor = distance * 1.0
//        let lineThickness = max(stroke.thickness * 0.8, 0.003) * distance
//        
//        let minX = stroke.points.map { $0.x }.min() ?? 0
//        let maxX = stroke.points.map { $0.x }.max() ?? 1
//        let minY = stroke.points.map { $0.y }.min() ?? 0
//        let maxY = stroke.points.map { $0.y }.max() ?? 1
//        
//        let centerX = (minX + maxX) / 2
//        let centerY = (minY + maxY) / 2
//        
//        let drawingWidth = maxX - minX
//        let drawingHeight = maxY - minY
//        let aspectRatio = Float(arView.bounds.width / arView.bounds.height)
//        
//        var points3D: [SCNVector3] = []
//        
//        for point in stroke.points {
//            let normalizedX = (point.x - centerX) * 2.0
//            let normalizedY = -(point.y - centerY) * 2.0
//            
//            let scaledX = normalizedX * scaleFactor
//            let scaledY = normalizedY * scaleFactor / aspectRatio
//            
//            points3D.append(SCNVector3(x: scaledX, y: scaledY, z: 0))
//        }
//        
//        let smoothedPoints = smoothPath(points: points3D, iterations: 2)
//        
//        for i in 0..<(smoothedPoints.count - 1) {
//            let start = smoothedPoints[i]
//            let end = smoothedPoints[i + 1]
//            
//            let cylinder = createCylinderBetween(
//                start: start,
//                end: end,
//                radius: lineThickness,
//                color: stroke.color.uiColor
//            )
//            strokeNode.addChildNode(cylinder)
//        }
//        
//        for (index, point) in smoothedPoints.enumerated() {
//            if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
//                let sphere = SCNSphere(radius: CGFloat(lineThickness * 1.2))
//                sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
//                sphere.firstMaterial?.lightingModel = .constant
//                sphere.firstMaterial?.emission.contents = stroke.color.uiColor
//                sphere.firstMaterial?.emission.intensity = 0.5
//                
//                let sphereNode = SCNNode(geometry: sphere)
//                sphereNode.position = point
//                strokeNode.addChildNode(sphereNode)
//            }
//        }
//        
//        strokeNode.simdTransform = anchorTransform
//        
//        let billboardConstraint = SCNBillboardConstraint()
//        billboardConstraint.freeAxes = [.X, .Y]
//        strokeNode.constraints = [billboardConstraint]
//        
//        return strokeNode
//    }
//    
//    private func smoothPath(points: [SCNVector3], iterations: Int = 1) -> [SCNVector3] {
//        guard points.count > 2 else { return points }
//        
//        var smoothed = points
//        
//        for _ in 0..<iterations {
//            var newPoints: [SCNVector3] = []
//            newPoints.append(smoothed[0])
//            
//            for i in 1..<(smoothed.count - 1) {
//                let prev = smoothed[i - 1]
//                let curr = smoothed[i]
//                let next = smoothed[i + 1]
//                
//                let smoothX = (prev.x + 2 * curr.x + next.x) / 4
//                let smoothY = (prev.y + 2 * curr.y + next.y) / 4
//                let smoothZ = (prev.z + 2 * curr.z + next.z) / 4
//                
//                newPoints.append(SCNVector3(x: smoothX, y: smoothY, z: smoothZ))
//            }
//            
//            newPoints.append(smoothed.last!)
//            smoothed = newPoints
//        }
//        
//        return smoothed
//    }
//    
//    private func createCylinderBetween(start: SCNVector3, end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
//        let distance = simd_distance(
//            simd_float3(start.x, start.y, start.z),
//            simd_float3(end.x, end.y, end.z)
//        )
//        
//        guard distance > 0 else { return SCNNode() }
//        
//        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(distance))
//        cylinder.radialSegmentCount = 16
//        
//        let material = SCNMaterial()
//        material.diffuse.contents = color
//        material.lightingModel = .constant
//        material.isDoubleSided = true
//        material.emission.contents = color
//        material.emission.intensity = 0.5
//        material.shininess = 0.0
//        
//        cylinder.materials = [material]
//        
//        let cylinderNode = SCNNode(geometry: cylinder)
//        
//        cylinderNode.position = SCNVector3(
//            x: (start.x + end.x) / 2,
//            y: (start.y + end.y) / 2,
//            z: (start.z + end.z) / 2
//        )
//        
//        let direction = simd_normalize(
//            simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
//        )
//        
//        let up = simd_float3(0, 1, 0)
//        let dot = simd_dot(up, direction)
//        
//        if abs(dot) > 0.999 {
//            cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
//        } else {
//            let axis = simd_normalize(simd_cross(up, direction))
//            let angle = acos(dot)
//            cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
//        }
//        
//        return cylinderNode
//    }
//    
//    private func createAccurateTransform(from screenPoint: CGPoint, distance: Float, in arView: ARSCNView, currentFrame: ARFrame) -> simd_float4x4 {
//        let cameraTransform = currentFrame.camera.transform
//        let intrinsics = currentFrame.camera.intrinsics
//        let imageResolution = currentFrame.camera.imageResolution
//        
//        let viewportSize = arView.bounds.size
//        let orientation = UIDevice.current.orientation
//        
//        var normalizedX = Float(screenPoint.x / viewportSize.width)
//        var normalizedY = Float(screenPoint.y / viewportSize.height)
//        
//        if orientation.isLandscape {
//            normalizedX = Float(screenPoint.y / viewportSize.height)
//            normalizedY = 1.0 - Float(screenPoint.x / viewportSize.width)
//        }
//        
//        let imageX = normalizedX * Float(imageResolution.width)
//        let imageY = normalizedY * Float(imageResolution.height)
//        
//        let projectedX = (imageX - intrinsics[2][0]) / intrinsics[0][0]
//        let projectedY = (imageY - intrinsics[2][1]) / intrinsics[1][1]
//        
//        let localRayDirection = simd_normalize(simd_float3(projectedX, projectedY, 1.0))
//        
//        let cameraRotation = simd_float3x3(
//            simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
//            simd_float3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
//            simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
//        )
//        
//        let worldRayDirection = simd_mul(cameraRotation, localRayDirection)
//        
//        let cameraPosition = simd_float3(cameraTransform.columns.3.x,
//                                        cameraTransform.columns.3.y,
//                                        cameraTransform.columns.3.z)
//        
//        let worldPosition = cameraPosition + worldRayDirection * distance
//        
//        var transform = matrix_identity_float4x4
//        transform.columns.3 = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
//        
//        let forward = -worldRayDirection
//        let worldUp = simd_float3(0, 1, 0)
//        let right = simd_normalize(simd_cross(worldUp, forward))
//        let up = simd_normalize(simd_cross(forward, right))
//        
//        transform.columns.0 = simd_float4(right.x, right.y, right.z, 0)
//        transform.columns.1 = simd_float4(up.x, up.y, up.z, 0)
//        transform.columns.2 = simd_float4(forward.x, forward.y, forward.z, 0)
//        
//        return transform
//    }
//    
//    func addDrawing(_ anchor: Drawing3DAnchor) {
//        guard let arView = arView else { return }
//        
//        removeDrawing(withId: anchor.id)
//        
//        let strokeNode = createStrokeNode(
//            from: anchor.stroke,
//            anchorTransform: anchor.worldTransform,
//            distance: anchor.distance
//        )
//        
//        activeDrawings[anchor.id] = strokeNode
//        arView.scene.rootNode.addChildNode(strokeNode)
//    }
//    
//    func updateDrawing(_ anchor: Drawing3DAnchor) {
//        removeDrawing(withId: anchor.id)
//        addDrawing(anchor)
//    }
//    
//    func removeDrawing(withId id: String) {
//        if let node = activeDrawings[id] {
//            node.removeFromParentNode()
//            activeDrawings.removeValue(forKey: id)
//        }
//    }
//    
//    func clearAllDrawings() {
//        for (_, node) in activeDrawings {
//            node.removeFromParentNode()
//        }
//        activeDrawings.removeAll()
//    }
//}
//
//struct Drawing3DAnchor {
//    let id: String
//    let worldTransform: simd_float4x4
//    let stroke: DrawingStroke
//    let distance: Float
//}















//import ARKit
//import SceneKit
//
//class DrawingManager: ObservableObject {
//    private var arView: ARSCNView?
//    private var activeDrawings: [String: SCNNode] = [:]
//    
//    @Published var isDrawingEnabled = true
//    @Published var currentTool = DrawingTool()
//    
//    func configure(with arView: ARSCNView) {
//        self.arView = arView
//    }
//    
//    func createDrawing3D(from stroke: DrawingStroke, at normalizedPoint: CGPoint) -> Drawing3DAnchor? {
//        guard let arView = arView,
//              let currentFrame = arView.session.currentFrame else { return nil }
//        
//        let screenPoints = stroke.points.map { point in
//            CGPoint(
//                x: CGFloat(point.x) * arView.bounds.width,
//                y: CGFloat(point.y) * arView.bounds.height
//            )
//        }
//        
//        var sumX: CGFloat = 0
//        var sumY: CGFloat = 0
//        for point in screenPoints {
//            sumX += point.x
//            sumY += point.y
//        }
//        let centerPoint = CGPoint(x: sumX / CGFloat(screenPoints.count), y: sumY / CGFloat(screenPoints.count))
//        
//        var hitDistance: Float = 2.0
//        var worldTransform = matrix_identity_float4x4
//        var foundHit = false
//        
//        let hitResults = arView.hitTest(centerPoint, types: [
//            .existingPlaneUsingGeometry,
//            .existingPlaneUsingExtent,
//            .estimatedHorizontalPlane,
//            .estimatedVerticalPlane,
//            .featurePoint
//        ])
//        
//        if let result = hitResults.first {
//            worldTransform = result.worldTransform
//            let hitPos = result.worldTransform.columns.3
//            let cameraPos = currentFrame.camera.transform.columns.3
//            hitDistance = simd_distance(
//                simd_float3(cameraPos.x, cameraPos.y, cameraPos.z),
//                simd_float3(hitPos.x, hitPos.y, hitPos.z)
//            )
//            foundHit = true
//        }
//        
//        if !foundHit {
//            if let query = arView.raycastQuery(
//                from: centerPoint,
//                allowing: .estimatedPlane,
//                alignment: .any
//            ) {
//                let results = arView.session.raycast(query)
//                if let raycastResult = results.first {
//                    worldTransform = raycastResult.worldTransform
//                    let cameraPosition = simd_float3(currentFrame.camera.transform.columns.3.x,
//                                                   currentFrame.camera.transform.columns.3.y,
//                                                   currentFrame.camera.transform.columns.3.z)
//                    
//                    let hitPosition = simd_float3(raycastResult.worldTransform.columns.3.x,
//                                                raycastResult.worldTransform.columns.3.y,
//                                                raycastResult.worldTransform.columns.3.z)
//                    
//                    hitDistance = simd_distance(cameraPosition, hitPosition)
//                    foundHit = true
//                }
//            }
//        }
//        
//        if !foundHit {
//            worldTransform = createAccurateTransform(
//                from: centerPoint,
//                distance: hitDistance,
//                in: arView,
//                currentFrame: currentFrame
//            )
//        }
//        
//        return Drawing3DAnchor(
//            id: stroke.id,
//            worldTransform: worldTransform,
//            stroke: stroke,
//            distance: hitDistance
//        )
//    }
//    
//    func createStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
//        let strokeNode = SCNNode()
//        
//        guard stroke.points.count > 1,
//              let arView = arView else { return strokeNode }
//        
//        let scaleFactor = distance * 0.3
//        let lineThickness = max(stroke.thickness * 0.4, 0.002) * distance * 0.5
//        
//        let minX = stroke.points.map { $0.x }.min() ?? 0
//        let maxX = stroke.points.map { $0.x }.max() ?? 1
//        let minY = stroke.points.map { $0.y }.min() ?? 0
//        let maxY = stroke.points.map { $0.y }.max() ?? 1
//        
//        let centerX = (minX + maxX) / 2
//        let centerY = (minY + maxY) / 2
//        
//        let drawingWidth = maxX - minX
//        let drawingHeight = maxY - minY
//        let aspectRatio = Float(arView.bounds.width / arView.bounds.height)
//        
//        var points3D: [SCNVector3] = []
//        
//        for point in stroke.points {
//            let normalizedX = (point.x - centerX) * 2.0
//            let normalizedY = -(point.y - centerY) * 2.0
//            
//            let scaledX = normalizedX * scaleFactor
//            let scaledY = normalizedY * scaleFactor / aspectRatio
//            
//            points3D.append(SCNVector3(x: scaledX, y: scaledY, z: 0))
//        }
//        
//        let smoothedPoints = smoothPath(points: points3D, iterations: 2)
//        
//        for i in 0..<(smoothedPoints.count - 1) {
//            let start = smoothedPoints[i]
//            let end = smoothedPoints[i + 1]
//            
//            let cylinder = createCylinderBetween(
//                start: start,
//                end: end,
//                radius: lineThickness,
//                color: stroke.color.uiColor
//            )
//            strokeNode.addChildNode(cylinder)
//        }
//        
//        for (index, point) in smoothedPoints.enumerated() {
//            if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
//                let sphere = SCNSphere(radius: CGFloat(lineThickness * 1.2))
//                sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
//                sphere.firstMaterial?.lightingModel = .constant
//                sphere.firstMaterial?.emission.contents = stroke.color.uiColor
//                sphere.firstMaterial?.emission.intensity = 0.5
//                
//                let sphereNode = SCNNode(geometry: sphere)
//                sphereNode.position = point
//                strokeNode.addChildNode(sphereNode)
//            }
//        }
//        
//        strokeNode.simdTransform = anchorTransform
//        
//        let billboardConstraint = SCNBillboardConstraint()
//        billboardConstraint.freeAxes = [.X, .Y]
//        strokeNode.constraints = [billboardConstraint]
//        
//        return strokeNode
//    }
//    
//    private func smoothPath(points: [SCNVector3], iterations: Int = 1) -> [SCNVector3] {
//        guard points.count > 2 else { return points }
//        
//        var smoothed = points
//        
//        for _ in 0..<iterations {
//            var newPoints: [SCNVector3] = []
//            newPoints.append(smoothed[0])
//            
//            for i in 1..<(smoothed.count - 1) {
//                let prev = smoothed[i - 1]
//                let curr = smoothed[i]
//                let next = smoothed[i + 1]
//                
//                let smoothX = (prev.x + 2 * curr.x + next.x) / 4
//                let smoothY = (prev.y + 2 * curr.y + next.y) / 4
//                let smoothZ = (prev.z + 2 * curr.z + next.z) / 4
//                
//                newPoints.append(SCNVector3(x: smoothX, y: smoothY, z: smoothZ))
//            }
//            
//            newPoints.append(smoothed.last!)
//            smoothed = newPoints
//        }
//        
//        return smoothed
//    }
//    
//    private func createCylinderBetween(start: SCNVector3, end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
//        let distance = simd_distance(
//            simd_float3(start.x, start.y, start.z),
//            simd_float3(end.x, end.y, end.z)
//        )
//        
//        guard distance > 0 else { return SCNNode() }
//        
//        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(distance))
//        cylinder.radialSegmentCount = 16
//        
//        let material = SCNMaterial()
//        material.diffuse.contents = color
//        material.lightingModel = .constant
//        material.isDoubleSided = true
//        material.emission.contents = color
//        material.emission.intensity = 0.5
//        material.shininess = 0.0
//        
//        cylinder.materials = [material]
//        
//        let cylinderNode = SCNNode(geometry: cylinder)
//        
//        cylinderNode.position = SCNVector3(
//            x: (start.x + end.x) / 2,
//            y: (start.y + end.y) / 2,
//            z: (start.z + end.z) / 2
//        )
//        
//        let direction = simd_normalize(
//            simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
//        )
//        
//        let up = simd_float3(0, 1, 0)
//        let dot = simd_dot(up, direction)
//        
//        if abs(dot) > 0.999 {
//            cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
//        } else {
//            let axis = simd_normalize(simd_cross(up, direction))
//            let angle = acos(dot)
//            cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
//        }
//        
//        return cylinderNode
//    }
//    
//    private func createAccurateTransform(from screenPoint: CGPoint, distance: Float, in arView: ARSCNView, currentFrame: ARFrame) -> simd_float4x4 {
//        let cameraTransform = currentFrame.camera.transform
//        let intrinsics = currentFrame.camera.intrinsics
//        let imageResolution = currentFrame.camera.imageResolution
//        
//        let viewportSize = arView.bounds.size
//        let orientation = UIDevice.current.orientation
//        
//        var normalizedX = Float(screenPoint.x / viewportSize.width)
//        var normalizedY = Float(screenPoint.y / viewportSize.height)
//        
//        if orientation.isLandscape {
//            normalizedX = Float(screenPoint.y / viewportSize.height)
//            normalizedY = 1.0 - Float(screenPoint.x / viewportSize.width)
//        }
//        
//        let imageX = normalizedX * Float(imageResolution.width)
//        let imageY = normalizedY * Float(imageResolution.height)
//        
//        let projectedX = (imageX - intrinsics[2][0]) / intrinsics[0][0]
//        let projectedY = (imageY - intrinsics[2][1]) / intrinsics[1][1]
//        
//        let localRayDirection = simd_normalize(simd_float3(projectedX, projectedY, 1.0))
//        
//        let cameraRotation = simd_float3x3(
//            simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
//            simd_float3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
//            simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
//        )
//        
//        let worldRayDirection = simd_mul(cameraRotation, localRayDirection)
//        
//        let cameraPosition = simd_float3(cameraTransform.columns.3.x,
//                                        cameraTransform.columns.3.y,
//                                        cameraTransform.columns.3.z)
//        
//        let worldPosition = cameraPosition + worldRayDirection * distance
//        
//        var transform = matrix_identity_float4x4
//        transform.columns.3 = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
//        
//        let forward = -worldRayDirection
//        let worldUp = simd_float3(0, 1, 0)
//        let right = simd_normalize(simd_cross(worldUp, forward))
//        let up = simd_normalize(simd_cross(forward, right))
//        
//        transform.columns.0 = simd_float4(right.x, right.y, right.z, 0)
//        transform.columns.1 = simd_float4(up.x, up.y, up.z, 0)
//        transform.columns.2 = simd_float4(forward.x, forward.y, forward.z, 0)
//        
//        return transform
//    }
//    
//    func addDrawing(_ anchor: Drawing3DAnchor) {
//        guard let arView = arView else { return }
//        
//        removeDrawing(withId: anchor.id)
//        
//        let strokeNode = createStrokeNode(
//            from: anchor.stroke,
//            anchorTransform: anchor.worldTransform,
//            distance: anchor.distance
//        )
//        
//        activeDrawings[anchor.id] = strokeNode
//        arView.scene.rootNode.addChildNode(strokeNode)
//    }
//    
//    func updateDrawing(_ anchor: Drawing3DAnchor) {
//        removeDrawing(withId: anchor.id)
//        addDrawing(anchor)
//    }
//    
//    func removeDrawing(withId id: String) {
//        if let node = activeDrawings[id] {
//            node.removeFromParentNode()
//            activeDrawings.removeValue(forKey: id)
//        }
//    }
//    
//    func clearAllDrawings() {
//        for (_, node) in activeDrawings {
//            node.removeFromParentNode()
//        }
//        activeDrawings.removeAll()
//    }
//}
//
//struct Drawing3DAnchor {
//    let id: String
//    let worldTransform: simd_float4x4
//    let stroke: DrawingStroke
//    let distance: Float
//}






import ARKit
import SceneKit

class DrawingManager: ObservableObject {
    private var arView: ARSCNView?
    private var activeDrawings: [String: SCNNode] = [:]
    
    @Published var isDrawingEnabled = true
    @Published var currentTool = DrawingTool()
    
    func configure(with arView: ARSCNView) {
        self.arView = arView
    }
    
    func createDrawing3D(from stroke: DrawingStroke, at normalizedPoint: CGPoint) -> Drawing3DAnchor? {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame else { return nil }
        
        let screenPoints = stroke.points.map { point in
            CGPoint(
                x: CGFloat(point.x) * arView.bounds.width,
                y: CGFloat(point.y) * arView.bounds.height
            )
        }
        
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for point in screenPoints {
            sumX += point.x
            sumY += point.y
        }
        let centerPoint = CGPoint(x: sumX / CGFloat(screenPoints.count), y: sumY / CGFloat(screenPoints.count))
        
        var hitDistance: Float = 2.0
        var worldTransform = matrix_identity_float4x4
        var foundHit = false
        
        let hitResults = arView.hitTest(centerPoint, types: [
            .existingPlaneUsingGeometry,
            .existingPlaneUsingExtent,
            .estimatedHorizontalPlane,
            .estimatedVerticalPlane,
            .featurePoint
        ])
        
        if let result = hitResults.first {
            worldTransform = result.worldTransform
            let hitPos = result.worldTransform.columns.3
            let cameraPos = currentFrame.camera.transform.columns.3
            hitDistance = simd_distance(
                simd_float3(cameraPos.x, cameraPos.y, cameraPos.z),
                simd_float3(hitPos.x, hitPos.y, hitPos.z)
            )
            foundHit = true
        }
        
        if !foundHit {
            if let query = arView.raycastQuery(
                from: centerPoint,
                allowing: .estimatedPlane,
                alignment: .any
            ) {
                let results = arView.session.raycast(query)
                if let raycastResult = results.first {
                    worldTransform = raycastResult.worldTransform
                    let cameraPosition = simd_float3(currentFrame.camera.transform.columns.3.x,
                                                   currentFrame.camera.transform.columns.3.y,
                                                   currentFrame.camera.transform.columns.3.z)
                    
                    let hitPosition = simd_float3(raycastResult.worldTransform.columns.3.x,
                                                raycastResult.worldTransform.columns.3.y,
                                                raycastResult.worldTransform.columns.3.z)
                    
                    hitDistance = simd_distance(cameraPosition, hitPosition)
                    foundHit = true
                }
            }
        }
        
        if !foundHit {
            worldTransform = createPreciseTransform(
                from: centerPoint,
                distance: hitDistance,
                in: arView,
                currentFrame: currentFrame
            )
        }
        
        return Drawing3DAnchor(
            id: stroke.id,
            worldTransform: worldTransform,
            stroke: stroke,
            distance: hitDistance
        )
    }
    
    func createStrokeNode(from stroke: DrawingStroke, anchorTransform: simd_float4x4, distance: Float) -> SCNNode {
        let strokeNode = SCNNode()
        
        guard stroke.points.count > 1,
              let arView = arView else { return strokeNode }
        
        let scaleFactor = distance * 0.28
        let lineThickness = max(stroke.thickness * 0.35, 0.0015) * distance * 0.5
        
        let minX = stroke.points.map { $0.x }.min() ?? 0
        let maxX = stroke.points.map { $0.x }.max() ?? 1
        let minY = stroke.points.map { $0.y }.min() ?? 0
        let maxY = stroke.points.map { $0.y }.max() ?? 1
        
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        
        let aspectRatio = Float(arView.bounds.width / arView.bounds.height)
        
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
                radius: lineThickness,
                color: stroke.color.uiColor
            )
            strokeNode.addChildNode(cylinder)
        }
        
        for (index, point) in smoothedPoints.enumerated() {
            if index == 0 || index == smoothedPoints.count - 1 || index % 5 == 0 {
                let sphere = SCNSphere(radius: CGFloat(lineThickness * 1.2))
                sphere.firstMaterial?.diffuse.contents = stroke.color.uiColor
                sphere.firstMaterial?.lightingModel = .constant
                sphere.firstMaterial?.emission.contents = stroke.color.uiColor
                sphere.firstMaterial?.emission.intensity = 0.5
                
                let sphereNode = SCNNode(geometry: sphere)
                sphereNode.position = point
                strokeNode.addChildNode(sphereNode)
            }
        }
        
        strokeNode.simdTransform = anchorTransform
        
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y]
        strokeNode.constraints = [billboardConstraint]
        
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
        material.emission.intensity = 0.5
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
    
    private func createPreciseTransform(from screenPoint: CGPoint, distance: Float, in arView: ARSCNView, currentFrame: ARFrame) -> simd_float4x4 {
        let cameraTransform = currentFrame.camera.transform
        let intrinsics = currentFrame.camera.intrinsics
        let imageResolution = currentFrame.camera.imageResolution
        
        let viewportSize = arView.bounds.size
        let orientation = UIDevice.current.orientation
        
        let viewAspectRatio = Float(viewportSize.width / viewportSize.height)
        let imageAspectRatio = Float(imageResolution.width / imageResolution.height)
        
        var adjustedX = Float(screenPoint.x)
        var adjustedY = Float(screenPoint.y)
        
        if abs(imageAspectRatio - viewAspectRatio) > 0.01 {
            if imageAspectRatio > viewAspectRatio {
                let scale = viewAspectRatio / imageAspectRatio
                let yOffset = (1.0 - scale) * 0.5
                adjustedY = Float(screenPoint.y / viewportSize.height - CGFloat(yOffset)) / scale * Float(viewportSize.height)
            } else {
                let scale = imageAspectRatio / viewAspectRatio
                let xOffset = (1.0 - scale) * 0.5
                adjustedX = Float(screenPoint.x / viewportSize.width - CGFloat(xOffset)) / scale * Float(viewportSize.width)
            }
        }
        
        var normalizedX = adjustedX / Float(viewportSize.width)
        var normalizedY = adjustedY / Float(viewportSize.height)
        
        if orientation.isLandscape {
            normalizedX = Float(screenPoint.y / viewportSize.height)
            normalizedY = 1.0 - Float(screenPoint.x / viewportSize.width)
        }
        
        let imageX = normalizedX * Float(imageResolution.width)
        let imageY = normalizedY * Float(imageResolution.height)
        
        let projectedX = (imageX - intrinsics[2][0]) / intrinsics[0][0]
        let projectedY = (imageY - intrinsics[2][1]) / intrinsics[1][1]
        
        let localRayDirection = simd_normalize(simd_float3(projectedX, projectedY, 1.0))
        
        let cameraRotation = simd_float3x3(
            simd_float3(cameraTransform.columns.0.x, cameraTransform.columns.0.y, cameraTransform.columns.0.z),
            simd_float3(cameraTransform.columns.1.x, cameraTransform.columns.1.y, cameraTransform.columns.1.z),
            simd_float3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
        )
        
        let worldRayDirection = simd_mul(cameraRotation, localRayDirection)
        
        let cameraPosition = simd_float3(cameraTransform.columns.3.x,
                                        cameraTransform.columns.3.y,
                                        cameraTransform.columns.3.z)
        
        let worldPosition = cameraPosition + worldRayDirection * distance
        
        var transform = matrix_identity_float4x4
        transform.columns.3 = simd_float4(worldPosition.x, worldPosition.y, worldPosition.z, 1.0)
        
        let forward = -worldRayDirection
        let worldUp = simd_float3(0, 1, 0)
        let right = simd_normalize(simd_cross(worldUp, forward))
        let up = simd_normalize(simd_cross(forward, right))
        
        transform.columns.0 = simd_float4(right.x, right.y, right.z, 0)
        transform.columns.1 = simd_float4(up.x, up.y, up.z, 0)
        transform.columns.2 = simd_float4(forward.x, forward.y, forward.z, 0)
        
        return transform
    }
    
    func addDrawing(_ anchor: Drawing3DAnchor) {
        guard let arView = arView else { return }
        
        removeDrawing(withId: anchor.id)
        
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
        if let node = activeDrawings[id] {
            node.removeFromParentNode()
            activeDrawings.removeValue(forKey: id)
        }
    }
    
    func clearAllDrawings() {
        for (_, node) in activeDrawings {
            node.removeFromParentNode()
        }
        activeDrawings.removeAll()
    }
}

struct Drawing3DAnchor {
    let id: String
    let worldTransform: simd_float4x4
    let stroke: DrawingStroke
    let distance: Float
}
