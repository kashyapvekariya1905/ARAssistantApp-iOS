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
    
    init(id: String = UUID().uuidString,
         points: [DrawingPoint] = [],
         color: UIColor = .systemBlue,
         thickness: Float = 0.01) {
        self.id = id
        self.points = points
        self.color = CodableColor(color: color)
        self.thickness = thickness
        self.timestamp = Date().timeIntervalSince1970
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
    }
    
    let type: String = "drawing"
    let action: Action
    let drawingId: String
    let stroke: DrawingStroke?
    let timestamp: TimeInterval
    
    init(action: Action, drawingId: String, stroke: DrawingStroke? = nil) {
        self.action = action
        self.drawingId = drawingId
        self.stroke = stroke
        self.timestamp = Date().timeIntervalSince1970
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
