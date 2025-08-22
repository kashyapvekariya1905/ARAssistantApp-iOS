//
//import ARKit
//import SceneKit
//
//class DrawingManager: ObservableObject {
//    private var arView: ARSCNView?
//    private var activeDrawings: [String: SCNNode] = [:]
//    private var drawingNodes: [String: [SCNNode]] = [:]
//    
//    @Published var isDrawingEnabled = true
//    @Published var currentTool = DrawingTool()
//    
//    func configure(with arView: ARSCNView) {
//        self.arView = arView
//    }
//    
//    func getARView() -> ARSCNView? {
//        return arView
//    }
//    
//    func processIncomingStroke(_ stroke: DrawingStroke) {
//        guard let arView = arView else { return }
//        
//        removeDrawing(withId: stroke.id)
//        
//        var strokeNodes: [SCNNode] = []
//        var worldPositions: [SCNVector3] = []
//        
//        for (index, point) in stroke.points.enumerated() {
//            let screenPoint = CGPoint(
//                x: CGFloat(point.x) * arView.bounds.width,
//                y: CGFloat(point.y) * arView.bounds.height
//            )
//            
//            let hitTestResults = arView.hitTest(screenPoint, types: [
//                .existingPlaneUsingExtent,
//                .existingPlaneUsingGeometry,
//                .estimatedHorizontalPlane,
//                .estimatedVerticalPlane,
//                .featurePoint
//            ])
//            
//            if let hitResult = hitTestResults.first {
//                let transform = hitResult.worldTransform
//                let position = SCNVector3(
//                    transform.columns.3.x,
//                    transform.columns.3.y,
//                    transform.columns.3.z
//                )
//                
//                worldPositions.append(position)
//                
//                let sphereRadius = CGFloat(stroke.thickness * 0.5)
//                let sphereGeometry = SCNSphere(radius: sphereRadius)
//                
//                let material = SCNMaterial()
//                material.diffuse.contents = stroke.color.uiColor
//                material.emission.contents = stroke.color.uiColor
//                material.emission.intensity = 0.2
//                material.lightingModel = .constant
//                
//                sphereGeometry.materials = [material]
//                
//                let sphereNode = SCNNode(geometry: sphereGeometry)
//                sphereNode.position = position
//                sphereNode.name = "stroke_\(stroke.id)_\(index)"
//                
//                arView.scene.rootNode.addChildNode(sphereNode)
//                strokeNodes.append(sphereNode)
//                
//                if index > 0 && index < stroke.points.count && worldPositions.count > 1 {
//                    let previousPosition = worldPositions[worldPositions.count - 2]
//                    let lineNode = createLineBetween(
//                        start: previousPosition,
//                        end: position,
//                        color: stroke.color.uiColor,
//                        thickness: CGFloat(stroke.thickness * 0.3)
//                    )
//                    lineNode.name = "stroke_line_\(stroke.id)_\(index)"
//                    arView.scene.rootNode.addChildNode(lineNode)
//                    strokeNodes.append(lineNode)
//                }
//            }
//        }
//        
//        drawingNodes[stroke.id] = strokeNodes
//        
//        if !worldPositions.isEmpty {
//            let centerX = worldPositions.reduce(0) { $0 + $1.x } / Float(worldPositions.count)
//            let centerY = worldPositions.reduce(0) { $0 + $1.y } / Float(worldPositions.count)
//            let centerZ = worldPositions.reduce(0) { $0 + $1.z } / Float(worldPositions.count)
//            
//            let centerPosition = simd_float3(centerX, centerY, centerZ)
//            
//            var transform = matrix_identity_float4x4
//            transform.columns.3 = simd_float4(centerPosition, 1.0)
//            
//            let distance = simd_distance(centerPosition, arView.pointOfView?.simdPosition ?? simd_float3(0, 0, 0))
//
//            
//            let anchorData = Drawing3DAnchorData(
//                worldTransform: transform,
//                distance: distance
//            )
//            
//            let render3DMessage = DrawingMessage(
//                action: .render3D,
//                drawingId: stroke.id,
//                stroke: stroke,
//                anchorData: anchorData
//            )
//            SocketManager.shared.sendDrawingMessage(render3DMessage)
//        }
//    }
//    
//    private func createLineBetween(start: SCNVector3, end: SCNVector3, color: UIColor, thickness: CGFloat) -> SCNNode {
//        let distance = simd_distance(
//            simd_float3(start.x, start.y, start.z),
//            simd_float3(end.x, end.y, end.z)
//        )
//        
//        guard distance > 0 else {
//            return SCNNode()
//        }
//        
//        let cylinder = SCNCylinder(radius: thickness, height: CGFloat(distance))
//        cylinder.radialSegmentCount = 8
//        
//        let material = SCNMaterial()
//        material.diffuse.contents = color
//        material.emission.contents = color
//        material.emission.intensity = 0.2
//        material.lightingModel = .constant
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
//    func removeDrawing(withId id: String) {
//        if let nodes = drawingNodes[id] {
//            nodes.forEach { $0.removeFromParentNode() }
//            drawingNodes.removeValue(forKey: id)
//        }
//        
//        arView?.scene.rootNode.childNodes.forEach { node in
//            if let name = node.name,
//               (name.hasPrefix("stroke_\(id)") || name.hasPrefix("stroke_line_\(id)")) {
//                node.removeFromParentNode()
//            }
//        }
//    }
//    
//    func clearAllDrawings() {
//        drawingNodes.values.forEach { nodes in
//            nodes.forEach { $0.removeFromParentNode() }
//        }
//        drawingNodes.removeAll()
//        
//        arView?.scene.rootNode.childNodes.forEach { node in
//            if let name = node.name,
//               (name.hasPrefix("stroke_") || name.hasPrefix("stroke_line_")) {
//                node.removeFromParentNode()
//            }
//        }
//    }
//}
//
//struct Drawing3DAnchor {
//    let id: String
//    let worldTransform: simd_float4x4
//    let stroke: DrawingStroke
//    let distance: Float
//}
//










import ARKit
import SceneKit

/**
 * DrawingManager handles 3D drawing placement and rendering in AR space
 *
 * This class manages:
 * - Converting 2D screen drawings to 3D AR-anchored objects
 * - Hit testing against AR surfaces to place drawings in real world
 * - Creating 3D geometry (spheres and cylinders) for stroke visualization
 * - Managing lifecycle of drawing nodes in the AR scene
 * - Communicating 3D anchor data back to remote devices
 */
class DrawingManager: ObservableObject {
    // MARK: - Private Properties
    private var arView: ARSCNView?                                    // Reference to the AR scene view
    private var activeDrawings: [String: SCNNode] = [:]              // Currently active drawing nodes (unused in current implementation)
    private var drawingNodes: [String: [SCNNode]] = [:]              // Maps drawing IDs to their SceneKit nodes
    
    // MARK: - Published Properties (Observable by SwiftUI)
    @Published var isDrawingEnabled = true                           // Whether drawing functionality is enabled
    @Published var currentTool = DrawingTool()                       // Current drawing tool settings
    
    // MARK: - Configuration
    
    /**
     * Configures the drawing manager with an ARSCNView
     * This must be called before processing any drawings
     * @param arView: The AR scene view where drawings will be placed
     */
    func configure(with arView: ARSCNView) {
        self.arView = arView
    }
    
    /**
     * Returns the configured ARSCNView for external access
     * @returns: Optional ARSCNView reference
     */
    func getARView() -> ARSCNView? {
        return arView
    }
    
    // MARK: - Drawing Processing
    
    /**
     * Processes an incoming 2D drawing stroke and places it in 3D AR space
     *
     * This is the core function that:
     * 1. Converts 2D screen coordinates to 3D world positions using AR hit testing
     * 2. Creates 3D geometry (spheres and cylinders) to represent the stroke
     * 3. Calculates anchor data for the stroke's position in world space
     * 4. Sends the 3D anchor information back to remote devices
     *
     * @param stroke: The 2D drawing stroke to be placed in AR
     */
    func processIncomingStroke(_ stroke: DrawingStroke) {
        guard let arView = arView else { return }
        
        // Remove any existing drawing with the same ID to prevent duplicates
        removeDrawing(withId: stroke.id)
        
        var strokeNodes: [SCNNode] = []              // Array to store all nodes created for this stroke
        var worldPositions: [SCNVector3] = []        // Array to store 3D world positions of stroke points
        
        // Process each point in the 2D stroke
        for (index, point) in stroke.points.enumerated() {
            // Convert normalized coordinates (0-1) to actual screen coordinates
            let screenPoint = CGPoint(
                x: CGFloat(point.x) * arView.bounds.width,
                y: CGFloat(point.y) * arView.bounds.height
            )
            
            // Perform AR hit testing to find real-world surfaces at this screen point
            let hitTestResults = arView.hitTest(screenPoint, types: [
                .existingPlaneUsingExtent,     // Detected planes with boundaries
                .existingPlaneUsingGeometry,   // Detected planes using full geometry
                .estimatedHorizontalPlane,     // Estimated horizontal surfaces (tables, floors)
                .estimatedVerticalPlane,       // Estimated vertical surfaces (walls)
                .featurePoint                  // Individual feature points in space
            ])
            
            // Use the first (closest) hit test result
            if let hitResult = hitTestResults.first {
                let transform = hitResult.worldTransform
                
                // Extract 3D position from the transform matrix
                let position = SCNVector3(
                    transform.columns.3.x,        // X coordinate from transform
                    transform.columns.3.y,        // Y coordinate from transform
                    transform.columns.3.z         // Z coordinate from transform
                )
                
                worldPositions.append(position)
                
                // Create a sphere at this 3D position to represent the stroke point
                let sphereRadius = CGFloat(stroke.thickness * 0.5)
                let sphereGeometry = SCNSphere(radius: sphereRadius)
                
                // Configure sphere material with stroke color and emission
                let material = SCNMaterial()
                material.diffuse.contents = stroke.color.uiColor      // Base color
                material.emission.contents = stroke.color.uiColor     // Glow color
                material.emission.intensity = 0.2                     // Subtle glow effect
                material.lightingModel = .constant                    // No lighting calculation for consistent appearance
                
                sphereGeometry.materials = [material]
                
                // Create scene node and position it
                let sphereNode = SCNNode(geometry: sphereGeometry)
                sphereNode.position = position
                sphereNode.name = "stroke_\(stroke.id)_\(index)"     // Unique name for identification
                
                // Add to AR scene and track in our array
                arView.scene.rootNode.addChildNode(sphereNode)
                strokeNodes.append(sphereNode)
                
                // Create cylinder connection between consecutive points
                if index > 0 && index < stroke.points.count && worldPositions.count > 1 {
                    let previousPosition = worldPositions[worldPositions.count - 2]
                    let lineNode = createLineBetween(
                        start: previousPosition,
                        end: position,
                        color: stroke.color.uiColor,
                        thickness: CGFloat(stroke.thickness * 0.3)    // Thinner than spheres for visual balance
                    )
                    lineNode.name = "stroke_line_\(stroke.id)_\(index)"
                    arView.scene.rootNode.addChildNode(lineNode)
                    strokeNodes.append(lineNode)
                }
            }
        }
        
        // Store all nodes created for this stroke for later management
        drawingNodes[stroke.id] = strokeNodes
        
        // Calculate anchor data for the entire stroke if we have valid world positions
        if !worldPositions.isEmpty {
            // Calculate center point of the stroke in 3D space
            let centerX = worldPositions.reduce(0) { $0 + $1.x } / Float(worldPositions.count)
            let centerY = worldPositions.reduce(0) { $0 + $1.y } / Float(worldPositions.count)
            let centerZ = worldPositions.reduce(0) { $0 + $1.z } / Float(worldPositions.count)
            
            let centerPosition = simd_float3(centerX, centerY, centerZ)
            
            // Create transform matrix for the stroke's anchor position
            var transform = matrix_identity_float4x4
            transform.columns.3 = simd_float4(centerPosition, 1.0)   // Set translation component
            
            // Calculate distance from camera for scaling purposes
            let distance = simd_distance(centerPosition, arView.pointOfView?.simdPosition ?? simd_float3(0, 0, 0))

            // Create anchor data structure
            let anchorData = Drawing3DAnchorData(
                worldTransform: transform,     // Transform matrix for positioning
                distance: distance            // Distance from camera for remote scaling
            )
            
            // Send 3D rendering message back to remote devices
            let render3DMessage = DrawingMessage(
                action: .render3D,            // Action type for 3D rendering
                drawingId: stroke.id,         // Unique stroke identifier
                stroke: stroke,               // Original stroke data
                anchorData: anchorData        // 3D anchor information
            )
            SocketManager.shared.sendDrawingMessage(render3DMessage)
        }
    }
    
    // MARK: - 3D Geometry Creation
    
    /**
     * Creates a cylinder between two 3D points to connect stroke segments
     *
     * This function:
     * 1. Calculates distance and direction between points
     * 2. Creates appropriately sized cylinder geometry
     * 3. Positions and orients the cylinder correctly in 3D space
     *
     * @param start: Starting 3D position
     * @param end: Ending 3D position
     * @param color: Color for the cylinder
     * @param thickness: Radius of the cylinder
     * @returns: SCNNode containing the positioned cylinder
     */
    private func createLineBetween(start: SCNVector3, end: SCNVector3, color: UIColor, thickness: CGFloat) -> SCNNode {
        // Calculate distance between the two points
        let distance = simd_distance(
            simd_float3(start.x, start.y, start.z),
            simd_float3(end.x, end.y, end.z)
        )
        
        // Return empty node if points are too close (avoid zero-length cylinders)
        guard distance > 0 else {
            return SCNNode()
        }
        
        // Create cylinder geometry with calculated height
        let cylinder = SCNCylinder(radius: thickness, height: CGFloat(distance))
        cylinder.radialSegmentCount = 8                      // Lower polygon count for performance
        
        // Configure cylinder material to match stroke appearance
        let material = SCNMaterial()
        material.diffuse.contents = color                    // Base color
        material.emission.contents = color                   // Glow color to match spheres
        material.emission.intensity = 0.2                    // Consistent glow intensity
        material.lightingModel = .constant                   // No lighting for consistent appearance
        
        cylinder.materials = [material]
        
        let cylinderNode = SCNNode(geometry: cylinder)
        
        // Position cylinder at midpoint between start and end
        cylinderNode.position = SCNVector3(
            x: (start.x + end.x) / 2,
            y: (start.y + end.y) / 2,
            z: (start.z + end.z) / 2
        )
        
        // Calculate direction vector for cylinder orientation
        let direction = simd_normalize(
            simd_float3(end.x - start.x, end.y - start.y, end.z - start.z)
        )
        
        // Default cylinder orientation is along Y-axis, need to rotate to align with direction
        let up = simd_float3(0, 1, 0)
        let dot = simd_dot(up, direction)                    // Dot product gives cosine of angle
        
        // Handle special case where direction is parallel to Y-axis
        if abs(dot) > 0.999 {
            cylinderNode.eulerAngles = SCNVector3(0, 0, dot > 0 ? 0 : Float.pi)
        } else {
            // Calculate rotation axis using cross product and angle using dot product
            let axis = simd_normalize(simd_cross(up, direction))
            let angle = acos(dot)                            // Angle between up vector and direction
            cylinderNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }
        
        return cylinderNode
    }
    
    // MARK: - Drawing Management
    
    /**
     * Removes all 3D nodes associated with a specific drawing ID
     * Cleans up both stored node references and scene graph
     * @param id: Unique identifier of the drawing to remove
     */
    func removeDrawing(withId id: String) {
        // Remove nodes tracked in our dictionary
        if let nodes = drawingNodes[id] {
            nodes.forEach { $0.removeFromParentNode() }
            drawingNodes.removeValue(forKey: id)
        }
        
        // Also search scene graph for any nodes with matching name patterns
        // This provides redundancy in case tracking gets out of sync
        arView?.scene.rootNode.childNodes.forEach { node in
            if let name = node.name,
               (name.hasPrefix("stroke_\(id)") || name.hasPrefix("stroke_line_\(id)")) {
                node.removeFromParentNode()
            }
        }
    }
    
    /**
     * Removes all drawings from the AR scene
     * Used for "clear all" functionality
     */
    func clearAllDrawings() {
        // Remove all tracked nodes
        drawingNodes.values.forEach { nodes in
            nodes.forEach { $0.removeFromParentNode() }
        }
        drawingNodes.removeAll()
        
        // Clean up any remaining stroke nodes in the scene graph
        arView?.scene.rootNode.childNodes.forEach { node in
            if let name = node.name,
               (name.hasPrefix("stroke_") || name.hasPrefix("stroke_line_")) {
                node.removeFromParentNode()
            }
        }
    }
}

// MARK: - Data Structures

/**
 * Drawing3DAnchor represents a drawing that has been anchored in 3D AR space
 * Contains all the information needed to recreate the drawing at its anchored position
 */
struct Drawing3DAnchor {
    let id: String                          // Unique identifier for the drawing
    let worldTransform: simd_float4x4      // 4x4 transform matrix defining position, rotation, and scale in world space
    let stroke: DrawingStroke              // Original 2D stroke data
    let distance: Float                    // Distance from camera when anchored (used for scaling)
}

/*
 * DrawingManager Architecture Overview:
 *
 * Workflow:
 * 1. Receives 2D drawing strokes from remote devices via socket
 * 2. Converts 2D screen coordinates to 3D world positions using AR hit testing
 * 3. Creates 3D geometry (spheres for points, cylinders for connections)
 * 4. Places geometry in AR scene at hit-tested positions
 * 5. Calculates anchor transform and sends back to remote for their 3D preview
 *
 * Key Technologies:
 * - ARKit: Provides world tracking and surface detection
 * - SceneKit: Handles 3D geometry creation and rendering
 * - Hit Testing: Maps 2D screen points to 3D world surfaces
 * - SIMD: Efficient vector/matrix math for 3D transformations
 *
 * Performance Considerations:
 * - Uses lower polygon counts (8 segments) for cylinders
 * - Constant lighting model avoids expensive lighting calculations
 * - Node tracking enables efficient cleanup
 * - Reuses geometry types (spheres/cylinders) for all strokes
 *
 * Visual Design:
 * - Spheres at stroke points for clear visibility
 * - Cylinders connecting points for continuous lines
 * - Emission materials provide glow effect
 * - Thickness scaling based on original stroke properties
 */
