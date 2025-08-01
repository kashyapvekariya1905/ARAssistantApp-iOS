
import Foundation
import UIKit
import simd

struct DrawingPoint: Codable {
    let x: Float
    let y: Float
    let force: Float
    let timestamp: TimeInterval
    
    init(normalizedPoint: CGPoint, force: Float = 1.0) {
        self.x = Float(normalizedPoint.x)
        self.y = Float(normalizedPoint.y)
        self.force = force
        self.timestamp = Date().timeIntervalSince1970
    }
}

struct DrawingStroke: Codable {
    let id: String
    var points: [DrawingPoint]
    let color: CodableColor
    let thickness: Float
    let timestamp: TimeInterval
    var depthInfo: StrokeDepthInfo?
    
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

struct StrokeDepthInfo: Codable {
    let centerDepth: Float
    let pointDepths: [Float]
    
    init(centerDepth: Float, pointDepths: [Float] = []) {
        self.centerDepth = centerDepth
        self.pointDepths = pointDepths
    }
}

struct CodableColor: Codable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    
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
    
    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green),
                blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}

struct DrawingMessage: Codable {
    enum Action: String, Codable {
        case add = "add"
        case update = "update"
        case remove = "remove"
        case render3D = "render_3d"
    }
    
    var type: String = "drawing"
    let action: Action
    let drawingId: String
    let stroke: DrawingStroke?
    let timestamp: TimeInterval
    let anchorData: Drawing3DAnchorData?
    
    init(action: Action, drawingId: String, stroke: DrawingStroke? = nil, anchorData: Drawing3DAnchorData? = nil) {
        self.action = action
        self.drawingId = drawingId
        self.stroke = stroke
        self.timestamp = Date().timeIntervalSince1970
        self.anchorData = anchorData
    }
}

struct Drawing3DAnchorData: Codable {
    let worldTransform: CodableTransform
    let distance: Float
    
    init(worldTransform: simd_float4x4, distance: Float) {
        self.worldTransform = CodableTransform(transform: worldTransform)
        self.distance = distance
    }
}

struct CodableTransform: Codable {
    let column0: [Float]
    let column1: [Float]
    let column2: [Float]
    let column3: [Float]
    
    init(transform: simd_float4x4) {
        self.column0 = [transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w]
        self.column1 = [transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w]
        self.column2 = [transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w]
        self.column3 = [transform.columns.3.x, transform.columns.3.y, transform.columns.3.z, transform.columns.3.w]
    }
    
    var simdTransform: simd_float4x4 {
        return simd_float4x4(columns: (
            simd_float4(column0[0], column0[1], column0[2], column0[3]),
            simd_float4(column1[0], column1[1], column1[2], column1[3]),
            simd_float4(column2[0], column2[1], column2[2], column2[3]),
            simd_float4(column3[0], column3[1], column3[2], column3[3])
        ))
    }
}

struct DrawingTool {
    var color: UIColor = .systemBlue
    var thickness: Float = 0.01
    var isEraser: Bool = false
    
    static let colors: [UIColor] = [
        .systemBlue, .systemRed, .systemGreen,
        .systemYellow, .systemPurple, .systemOrange,
        .white, .black
    ]
    
    static let thicknesses: [Float] = [0.008, 0.012, 0.016, 0.020]
}

