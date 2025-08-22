//
//import Foundation
//import UIKit
//import simd
//
//struct DrawingPoint: Codable {
//    let x: Float
//    let y: Float
//    let force: Float
//    let timestamp: TimeInterval
//    
//    init(normalizedPoint: CGPoint, force: Float = 1.0) {
//        self.x = Float(normalizedPoint.x)
//        self.y = Float(normalizedPoint.y)
//        self.force = force
//        self.timestamp = Date().timeIntervalSince1970
//    }
//}
//
//struct DrawingStroke: Codable {
//    let id: String
//    var points: [DrawingPoint]
//    let color: CodableColor
//    let thickness: Float
//    let timestamp: TimeInterval
//    var depthInfo: StrokeDepthInfo?
//    
//    init(id: String = UUID().uuidString,
//         points: [DrawingPoint] = [],
//         color: UIColor = .systemBlue,
//         thickness: Float = 0.01,
//         depthInfo: StrokeDepthInfo? = nil) {
//        self.id = id
//        self.points = points
//        self.color = CodableColor(color: color)
//        self.thickness = thickness
//        self.timestamp = Date().timeIntervalSince1970
//        self.depthInfo = depthInfo
//    }
//}
//
//struct StrokeDepthInfo: Codable {
//    let centerDepth: Float
//    let pointDepths: [Float]
//    
//    init(centerDepth: Float, pointDepths: [Float] = []) {
//        self.centerDepth = centerDepth
//        self.pointDepths = pointDepths
//    }
//}
//
//struct CodableColor: Codable {
//    let red: Float
//    let green: Float
//    let blue: Float
//    let alpha: Float
//    
//    init(color: UIColor) {
//        var r: CGFloat = 0
//        var g: CGFloat = 0
//        var b: CGFloat = 0
//        var a: CGFloat = 0
//        color.getRed(&r, green: &g, blue: &b, alpha: &a)
//        
//        self.red = Float(r)
//        self.green = Float(g)
//        self.blue = Float(b)
//        self.alpha = Float(a)
//    }
//    
//    var uiColor: UIColor {
//        UIColor(red: CGFloat(red), green: CGFloat(green),
//                blue: CGFloat(blue), alpha: CGFloat(alpha))
//    }
//}
//
//struct DrawingMessage: Codable {
//    enum Action: String, Codable {
//        case add = "add"
//        case update = "update"
//        case remove = "remove"
//        case render3D = "render_3d"
//    }
//    
//    var type: String = "drawing"
//    let action: Action
//    let drawingId: String
//    let stroke: DrawingStroke?
//    let timestamp: TimeInterval
//    let anchorData: Drawing3DAnchorData?
//    
//    init(action: Action, drawingId: String, stroke: DrawingStroke? = nil, anchorData: Drawing3DAnchorData? = nil) {
//        self.action = action
//        self.drawingId = drawingId
//        self.stroke = stroke
//        self.timestamp = Date().timeIntervalSince1970
//        self.anchorData = anchorData
//    }
//}
//
//struct Drawing3DAnchorData: Codable {
//    let worldTransform: CodableTransform
//    let distance: Float
//    
//    init(worldTransform: simd_float4x4, distance: Float) {
//        self.worldTransform = CodableTransform(transform: worldTransform)
//        self.distance = distance
//    }
//}
//
//struct CodableTransform: Codable {
//    let column0: [Float]
//    let column1: [Float]
//    let column2: [Float]
//    let column3: [Float]
//    
//    init(transform: simd_float4x4) {
//        self.column0 = [transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w]
//        self.column1 = [transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w]
//        self.column2 = [transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w]
//        self.column3 = [transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w]
//    }
//    
//    var simdTransform: simd_float4x4 {
//        return simd_float4x4(columns: (
//            simd_float4(column0[0], column0[1], column0[2], column0[3]),
//            simd_float4(column1[0], column1[1], column1[2], column1[3]),
//            simd_float4(column2[0], column2[1], column2[2], column2[3]),
//            simd_float4(column3[0], column3[1], column3[2], column3[3])
//        ))
//    }
//}
//
//struct DrawingTool {
//    var color: UIColor = .systemBlue
//    var thickness: Float = 0.01
//    var isEraser: Bool = false
//    
//    static let colors: [UIColor] = [
//        .systemBlue, .systemRed, .systemGreen,
//        .systemYellow, .systemPurple, .systemOrange,
//        .white, .black
//    ]
//    
//    static let thicknesses: [Float] = [0.008, 0.012, 0.016, 0.020]
//}
//













import Foundation
import UIKit
import simd

// MARK: - Drawing Point Structure
/// Represents a single point in a drawing stroke with position, pressure, and timing information
struct DrawingPoint: Codable {
    let x: Float              // Normalized X coordinate (0.0 to 1.0)
    let y: Float              // Normalized Y coordinate (0.0 to 1.0)
    let force: Float          // Pressure/force applied at this point (0.0 to 1.0)
    let timestamp: TimeInterval // When this point was captured
    
    /// Initialize a drawing point from a normalized CGPoint
    /// - Parameters:
    ///   - normalizedPoint: Point with coordinates between 0.0 and 1.0
    ///   - force: Pressure applied (defaults to 1.0 for full pressure)
    init(normalizedPoint: CGPoint, force: Float = 1.0) {
        self.x = Float(normalizedPoint.x)
        self.y = Float(normalizedPoint.y)
        self.force = force
        self.timestamp = Date().timeIntervalSince1970
    }
}

// MARK: - Drawing Stroke Structure
/// Represents a complete drawing stroke containing multiple points with styling information
struct DrawingStroke: Codable {
    let id: String                    // Unique identifier for this stroke
    var points: [DrawingPoint]        // Array of points that make up the stroke
    let color: CodableColor          // Color of the stroke
    let thickness: Float             // Thickness/width of the stroke
    let timestamp: TimeInterval      // When this stroke was created
    var depthInfo: StrokeDepthInfo?  // Optional 3D depth information
    
    /// Initialize a new drawing stroke
    /// - Parameters:
    ///   - id: Unique identifier (generates UUID if not provided)
    ///   - points: Array of drawing points (empty by default)
    ///   - color: Stroke color (defaults to system blue)
    ///   - thickness: Stroke thickness (defaults to 0.01)
    ///   - depthInfo: Optional 3D depth information
    init(id: String = UUID().uuidString,
         points: [DrawingPoint] = [],
         color: UIColor = .systemBlue,
         thickness: Float = 0.01,
         depthInfo: StrokeDepthInfo? = nil) {
        self.id = id
        self.points = points
        self.color = CodableColor(color: color)
        self.thickness = thickness
        self.timestamp = Date().timeIntervalSince1970
        self.depthInfo = depthInfo
    }
}

// MARK: - Stroke Depth Information
/// Contains 3D depth information for a stroke, used for spatial drawing applications
struct StrokeDepthInfo: Codable {
    let centerDepth: Float      // Depth of the stroke's center point
    let pointDepths: [Float]    // Individual depth values for each point in the stroke
    
    /// Initialize depth information for a stroke
    /// - Parameters:
    ///   - centerDepth: Central depth value for the stroke
    ///   - pointDepths: Array of depth values for individual points (empty by default)
    init(centerDepth: Float, pointDepths: [Float] = []) {
        self.centerDepth = centerDepth
        self.pointDepths = pointDepths
    }
}

// MARK: - Codable Color Wrapper
/// A Codable wrapper for UIColor that can be serialized/deserialized
struct CodableColor: Codable {
    let red: Float      // Red component (0.0 to 1.0)
    let green: Float    // Green component (0.0 to 1.0)
    let blue: Float     // Blue component (0.0 to 1.0)
    let alpha: Float    // Alpha/transparency component (0.0 to 1.0)
    
    /// Initialize from a UIColor by extracting RGBA components
    /// - Parameter color: The UIColor to convert
    init(color: UIColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        self.red = Float(r)
        self.green = Float(g)
        self.blue = Float(b)
        self.alpha = Float(a)
    }
    
    /// Convert back to UIColor for use in UI components
    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green),
                blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

// MARK: - Drawing Message Structure
/// Message structure for communicating drawing actions between components
struct DrawingMessage: Codable {
    /// Enum defining possible drawing actions
    enum Action: String, Codable {
        case add = "add"           // Add a new stroke
        case update = "update"     // Update an existing stroke
        case remove = "remove"     // Remove a stroke
        case render3D = "render_3d" // Trigger 3D rendering
    }
    
    var type: String = "drawing"                    // Message type identifier
    let action: Action                              // The action to perform
    let drawingId: String                          // ID of the drawing being modified
    let stroke: DrawingStroke?                     // Optional stroke data
    let timestamp: TimeInterval                    // When this message was created
    let anchorData: Drawing3DAnchorData?          // Optional 3D anchor information
    
    /// Initialize a drawing message
    /// - Parameters:
    ///   - action: The drawing action to perform
    ///   - drawingId: Identifier for the target drawing
    ///   - stroke: Optional stroke data for add/update actions
    ///   - anchorData: Optional 3D positioning data
    init(action: Action, drawingId: String, stroke: DrawingStroke? = nil, anchorData: Drawing3DAnchorData? = nil) {
        self.action = action
        self.drawingId = drawingId
        self.stroke = stroke
        self.timestamp = Date().timeIntervalSince1970
        self.anchorData = anchorData
    }
}

// MARK: - 3D Anchor Data Structure
/// Contains 3D positioning information for anchoring drawings in 3D space
struct Drawing3DAnchorData: Codable {
    let worldTransform: CodableTransform    // 4x4 transformation matrix for 3D positioning
    let distance: Float                     // Distance from the viewer/camera
    
    /// Initialize 3D anchor data
    /// - Parameters:
    ///   - worldTransform: 4x4 matrix defining position, rotation, and scale in 3D space
    ///   - distance: Distance from the viewing position
    init(worldTransform: simd_float4x4, distance: Float) {
        self.worldTransform = CodableTransform(transform: worldTransform)
        self.distance = distance
    }
}

// MARK: - Codable Transform Matrix
/// A Codable wrapper for simd_float4x4 transformation matrices
struct CodableTransform: Codable {
    let column0: [Float]    // First column of the 4x4 matrix
    let column1: [Float]    // Second column of the 4x4 matrix
    let column2: [Float]    // Third column of the 4x4 matrix
    let column3: [Float]    // Fourth column of the 4x4 matrix
    
    /// Initialize from a simd_float4x4 matrix by extracting column data
    /// - Parameter transform: The 4x4 transformation matrix to convert
    init(transform: simd_float4x4) {
        self.column0 = [transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w]
        self.column1 = [transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w]
        self.column2 = [transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w]
        self.column3 = [transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w]
    }
    
    /// Convert back to simd_float4x4 for use in 3D calculations
    var simdTransform: simd_float4x4 {
        return simd_float4x4(columns: (
            simd_float4(column0[0], column0[1], column0[2], column0[3]),
            simd_float4(column1[0], column1[1], column1[2], column1[3]),
            simd_float4(column2[0], column2[1], column2[2], column2[3]),
            simd_float4(column3[0], column3[1], column3[2], column3[3])
        ))
    }
}

// MARK: - Drawing Tool Configuration
/// Configuration structure for drawing tools with color, thickness, and mode settings
struct DrawingTool {
    var color: UIColor = .systemBlue    // Currently selected drawing color
    var thickness: Float = 0.01         // Currently selected brush thickness
    var isEraser: Bool = false          // Whether the tool is in eraser mode
    
    /// Predefined color palette for the drawing tool
    static let colors: [UIColor] = [
        .systemBlue, .systemRed, .systemGreen,
        .systemYellow, .systemPurple, .systemOrange,
        .white, .black
    ]
    
    /// Predefined thickness options for the drawing tool
    static let thicknesses: [Float] = [0.008, 0.012, 0.016, 0.020]
}
