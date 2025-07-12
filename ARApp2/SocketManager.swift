import Foundation
import UIKit

class SocketManager: ObservableObject {
    static let shared = SocketManager()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    
    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"
    
    // Callbacks
    var onImageReceived: ((UIImage) -> Void)?
    var onDrawingReceived: ((DrawingMessage) -> Void)?
    var onClearDrawings: (() -> Void)?
    
    private init() {}
    
    func connect(as role: String, id: String = UUID().uuidString) {
        guard let url = URL(string: "ws://172.26.102.151:3000") else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Send registration message
        let registration = [
            "type": "register",
            "role": role,
            "id": id
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: registration) {
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { [weak self] error in
                if let error = error {
                    print("Registration error: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.isConnected = true
                        self?.connectionStatus = "Connected as \(role)"
                    }
                }
            }
        }
        
        // Start receiving messages
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
    }
    
    func sendImageData(_ imageData: Data) {
        guard isConnected else { return }
        
        let message = URLSessionWebSocketTask.Message.data(imageData)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }
    
    func sendDrawingMessage(_ drawingMessage: DrawingMessage) {
        guard isConnected else { return }
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(drawingMessage)
            let message = URLSessionWebSocketTask.Message.data(data)
            
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Send drawing error: \(error)")
                }
            }
        } catch {
            print("Encoding error: \(error)")
        }
    }
    
    func sendClearDrawings() {
        guard isConnected else { return }
        
        let clearMessage = ["type": "clear_drawings"]
        
        if let data = try? JSONSerialization.data(withJSONObject: clearMessage) {
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Send clear error: \(error)")
                }
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleReceivedData(data)
                case .string(let text):
                    self?.handleReceivedText(text)
                @unknown default:
                    break
                }
                // Continue receiving
                self?.receiveMessage()
                
            case .failure(let error):
                print("Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionStatus = "Connection error"
                }
            }
        }
    }
    
    private func handleReceivedData(_ data: Data) {
        // First try to decode as JSON (drawing message)
        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }
        
        // Otherwise, treat as image data
        if let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.onImageReceived?(image)
            }
        }
    }
    
    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        // Try to decode as DrawingMessage first
        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }
        
        // Handle other JSON messages
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let type = json["type"] as? String {
                switch type {
                case "registered":
                    print("Successfully registered")
                    
                case "status":
                    if let users = json["connectedUsers"] as? Int,
                       let aids = json["connectedAids"] as? Int {
                        DispatchQueue.main.async {
                            self.connectionStatus = "Users: \(users), Aids: \(aids)"
                        }
                    }
                    
                case "drawing":
                    // Handle drawing message
                    if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
                        DispatchQueue.main.async {
                            self.onDrawingReceived?(drawingMessage)
                        }
                    }
                    
                case "clear_drawings":
                    DispatchQueue.main.async {
                        self.onClearDrawings?()
                    }
                    
                case "drawing_history":
                    // Handle drawing history for late-joining users
                    if let drawings = json["drawings"] as? [[String: Any]] {
                        for drawingData in drawings {
                            if let jsonData = try? JSONSerialization.data(withJSONObject: drawingData),
                               let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: jsonData) {
                                DispatchQueue.main.async {
                                    self.onDrawingReceived?(drawingMessage)
                                }
                            }
                        }
                    }
                    
                default:
                    break
                }
            }
        }
    }
}
