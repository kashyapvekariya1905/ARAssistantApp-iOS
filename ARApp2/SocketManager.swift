//
//import Foundation
//import UIKit
//
//class SocketManager: ObservableObject {
//    static let shared = SocketManager()
//
//    private var webSocketTask: URLSessionWebSocketTask?
//    private let session = URLSession(configuration: .default)
//
//    @Published var isConnected = false
//    @Published var connectionStatus = "Disconnected"
//
//    var onImageReceived: ((UIImage) -> Void)?
//    var onDrawingReceived: ((DrawingMessage) -> Void)?
//    var onClearDrawings: (() -> Void)?
//    var onAudioReceived: ((Data) -> Void)?
//    var onAudioCommandReceived: ((AudioCommand) -> Void)?
//    var onFeedbackReceived: ((UIImage) -> Void)?
//
//    private init() {}
//
//    func connect(as role: String, id: String = UUID().uuidString) {
//        guard let url = URL(string: "ws://192.168.10.179:3000") else { return }
////        guard let url = URL(string: "ws://172.26.102.151:3000") else { return }
//        
//
//        webSocketTask = session.webSocketTask(with: url)
//        webSocketTask?.resume()
//
//        let registration = [
//            "type": "register",
//            "role": role,
//            "id": id
//        ]
//
//        if let data = try? JSONSerialization.data(withJSONObject: registration) {
//            let message = URLSessionWebSocketTask.Message.data(data)
//            webSocketTask?.send(message) { [weak self] error in
//                if let error = error {
//                    print("Registration error: \(error)")
//                } else {
//                    DispatchQueue.main.async {
//                        self?.isConnected = true
//                        self?.connectionStatus = "Connected as \(role)"
//                    }
//                }
//            }
//        }
//
//        receiveMessage()
//    }
//
//    func disconnect() {
//        webSocketTask?.cancel(with: .goingAway, reason: nil)
//        DispatchQueue.main.async {
//            self.isConnected = false
//            self.connectionStatus = "Disconnected"
//        }
//    }
//
//    func sendImageData(_ imageData: Data) {
//        guard isConnected else { return }
//
//        let message = URLSessionWebSocketTask.Message.data(imageData)
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("Send error: \(error)")
//            }
//        }
//    }
//
//    func sendDrawingMessage(_ drawingMessage: DrawingMessage) {
//        guard isConnected else { return }
//
//        do {
//            let encoder = JSONEncoder()
//            let data = try encoder.encode(drawingMessage)
//            let message = URLSessionWebSocketTask.Message.data(data)
//
//            webSocketTask?.send(message) { error in
//                if let error = error {
//                    print("Send drawing error: \(error)")
//                }
//            }
//        } catch {
//            print("Encoding error: \(error)")
//        }
//    }
//
//    func sendClearDrawings() {
//        guard isConnected else { return }
//
//        let clearMessage = ["type": "clear_drawings"]
//
//        if let data = try? JSONSerialization.data(withJSONObject: clearMessage) {
//            let message = URLSessionWebSocketTask.Message.data(data)
//            webSocketTask?.send(message) { error in
//                if let error = error {
//                    print("Send clear error: \(error)")
//                } else {
//                    print("Clear drawings sent successfully")
//                }
//            }
//        }
//    }
//
//    func sendAudioData(_ audioData: Data) {
//        guard isConnected else { return }
//
//        var message = Data()
//        message.append(contentsOf: "AUDIO:".utf8)
//        message.append(audioData)
//
//        let wsMessage = URLSessionWebSocketTask.Message.data(message)
//        webSocketTask?.send(wsMessage) { error in
//            if let error = error {
//                print("Send audio error: \(error)")
//            }
//        }
//    }
//
//    func sendAudioCommand(_ command: AudioCommand) {
//        guard isConnected else { return }
//
//        let commandMessage = ["type": "audio_command", "command": command.rawValue]
//
//        if let data = try? JSONSerialization.data(withJSONObject: commandMessage) {
//            let message = URLSessionWebSocketTask.Message.data(data)
//            webSocketTask?.send(message) { error in
//                if let error = error {
//                    print("Send audio command error: \(error)")
//                }
//            }
//        }
//    }
//    
//    func sendFeedbackData(_ feedbackData: Data) {
//        guard isConnected else { return }
//
//        let message = URLSessionWebSocketTask.Message.data(feedbackData)
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("Send feedback error: \(error)")
//            }
//        }
//    }
//
//    private func receiveMessage() {
//        webSocketTask?.receive { [weak self] result in
//            switch result {
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    self?.handleReceivedData(data)
//                case .string(let text):
//                    self?.handleReceivedText(text)
//                @unknown default:
//                    break
//                }
//                self?.receiveMessage()
//
//            case .failure(let error):
//                print("Receive error: \(error)")
//                DispatchQueue.main.async {
//                    self?.isConnected = false
//                    self?.connectionStatus = "Connection error"
//                }
//            }
//        }
//    }
//
//    private func handleReceivedData(_ data: Data) {
//        if let audioPrefix = "AUDIO:".data(using: .utf8), data.starts(with: audioPrefix) {
//            let audioData = data.dropFirst(audioPrefix.count)
//            DispatchQueue.main.async {
//                self.onAudioReceived?(audioData)
//            }
//            return
//        }
//        
//        if let feedbackPrefix = "FEEDBACK:".data(using: .utf8), data.starts(with: feedbackPrefix) {
//            let imageData = data.dropFirst(feedbackPrefix.count)
//            if let image = UIImage(data: imageData) {
//                DispatchQueue.main.async {
//                    self.onFeedbackReceived?(image)
//                }
//            }
//            return
//        }
//
//        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
//            DispatchQueue.main.async {
//                self.onDrawingReceived?(drawingMessage)
//            }
//            return
//        }
//        
//        if let text = String(data: data, encoding: .utf8) {
//            handleReceivedText(text)
//            return
//        }
//
//        if let image = UIImage(data: data) {
//            DispatchQueue.main.async {
//                self.onImageReceived?(image)
//            }
//        }
//    }
//    func sendRawData(_ data: Data) {
//        guard isConnected else { return }
//        webSocketTask?.send(.data(data)) { error in
//            if let error = error {
//                print("WebSocket send error: \(error)")
//            }
//        }
//    }
//
//    func sendChunkedMessage(_ message: [String: Any]) {
//        if let jsonData = try? JSONSerialization.data(withJSONObject: message) {
//            sendRawData(jsonData)
//        }
//    }
//
//    private func handleReceivedText(_ text: String) {
//        guard let data = text.data(using: .utf8) else { return }
//
//        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
//            DispatchQueue.main.async {
//                self.onDrawingReceived?(drawingMessage)
//            }
//            return
//        }
//
//        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//           let type = json["type"] as? String {
//            switch type {
//            case "registered":
//                print("Successfully registered")
//
//            case "status":
//                if let users = json["connectedUsers"] as? Int,
//                   let aids = json["connectedAids"] as? Int {
//                    DispatchQueue.main.async {
//                        self.connectionStatus = "Users: \(users), Aids: \(aids)"
//                    }
//                }
//
//            case "clear_drawings":
//                print("Received clear drawings command")
//                DispatchQueue.main.async {
//                    self.onClearDrawings?()
//                }
//
//            case "audio_command":
//                if let commandRaw = json["command"] as? String,
//                   let command = AudioCommand(rawValue: commandRaw) {
//                    DispatchQueue.main.async {
//                        self.onAudioCommandReceived?(command)
//                    }
//                }
//
//            default:
//                break
//            }
//        }
//    }
//}
//
//enum AudioCommand: String {
//    case start = "audio_start"
//    case end = "audio_end"
//}
//
//



















import Foundation
import UIKit

// MARK: - Socket Manager Class
/// Manages WebSocket connections for real-time communication between devices
/// Handles sending and receiving images, drawings, audio data, and commands
class SocketManager: ObservableObject {
    // Singleton instance for app-wide socket management
    static let shared = SocketManager()

    // WebSocket connection and session management
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    // Published properties for SwiftUI reactivity
    @Published var isConnected = false              // Current connection state
    @Published var connectionStatus = "Disconnected" // Human-readable connection status

    // MARK: - Callback Closures
    /// Callback handlers for different types of received data
    var onImageReceived: ((UIImage) -> Void)?           // Handles received image data
    var onDrawingReceived: ((DrawingMessage) -> Void)?  // Handles received drawing messages
    var onClearDrawings: (() -> Void)?                  // Handles clear drawings command
    var onAudioReceived: ((Data) -> Void)?             // Handles received audio data
    var onAudioCommandReceived: ((AudioCommand) -> Void)? // Handles audio control commands
    var onFeedbackReceived: ((UIImage) -> Void)?       // Handles feedback image data

    // Private initializer to enforce singleton pattern
    private init() {}

    // MARK: - Connection Management
    /// Establishes WebSocket connection and registers the client with a specific role
    /// - Parameters:
    ///   - role: The role of this client (e.g., "user", "aid", "viewer")
    ///   - id: Unique identifier for this client (generates UUID if not provided)
    func connect(as role: String, id: String = UUID().uuidString) {
        // WebSocket server URL - currently set to local network address
        guard let url = URL(string: "ws://192.168.10.179:3000") else { return }
//        guard let url = URL(string: "ws://172.26.102.151:3000") else { return }
        
        // Create and start WebSocket connection
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Create registration message to identify this client to the server
        let registration = [
            "type": "register",    // Message type for server routing
            "role": role,          // Client role for permission/routing logic
            "id": id              // Unique client identifier
        ]

        // Send registration message as JSON data
        if let data = try? JSONSerialization.data(withJSONObject: registration) {
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { [weak self] error in
                if let error = error {
                    print("Registration error: \(error)")
                } else {
                    // Update UI state on successful registration
                    DispatchQueue.main.async {
                        self?.isConnected = true
                        self?.connectionStatus = "Connected as \(role)"
                    }
                }
            }
        }

        // Start listening for incoming messages
        receiveMessage()
    }

    /// Disconnects from the WebSocket server
    func disconnect() {
        // Close WebSocket connection gracefully
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        // Update UI state on main thread
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "Disconnected"
        }
    }

    // MARK: - Data Sending Methods
    /// Sends raw image data through the WebSocket connection
    /// - Parameter imageData: Binary image data to transmit
    func sendImageData(_ imageData: Data) {
        guard isConnected else { return } // Only send if connected

        let message = URLSessionWebSocketTask.Message.data(imageData)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }

    /// Sends a drawing message (add, update, remove strokes) as JSON
    /// - Parameter drawingMessage: The drawing operation to transmit
    func sendDrawingMessage(_ drawingMessage: DrawingMessage) {
        guard isConnected else { return } // Only send if connected

        do {
            // Encode drawing message to JSON
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

    /// Sends a command to clear all drawings on connected devices
    func sendClearDrawings() {
        guard isConnected else { return } // Only send if connected

        // Create simple command message
        let clearMessage = ["type": "clear_drawings"]

        if let data = try? JSONSerialization.data(withJSONObject: clearMessage) {
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Send clear error: \(error)")
                } else {
                    print("Clear drawings sent successfully")
                }
            }
        }
    }

    /// Sends audio data with a special prefix for server identification
    /// - Parameter audioData: Binary audio data to transmit
    func sendAudioData(_ audioData: Data) {
        guard isConnected else { return } // Only send if connected

        // Prepend "AUDIO:" prefix so server can identify audio data
        var message = Data()
        message.append(contentsOf: "AUDIO:".utf8)
        message.append(audioData)

        let wsMessage = URLSessionWebSocketTask.Message.data(message)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("Send audio error: \(error)")
            }
        }
    }

    /// Sends audio control commands (start/stop recording, etc.)
    /// - Parameter command: The audio command to send
    func sendAudioCommand(_ command: AudioCommand) {
        guard isConnected else { return } // Only send if connected

        // Create command message with type and command value
        let commandMessage = ["type": "audio_command", "command": command.rawValue]

        if let data = try? JSONSerialization.data(withJSONObject: commandMessage) {
            let message = URLSessionWebSocketTask.Message.data(data)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("Send audio command error: \(error)")
                }
            }
        }
    }
    
    /// Sends feedback data (typically images) to other connected devices
    /// - Parameter feedbackData: Binary feedback data to transmit
    func sendFeedbackData(_ feedbackData: Data) {
        guard isConnected else { return } // Only send if connected

        let message = URLSessionWebSocketTask.Message.data(feedbackData)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send feedback error: \(error)")
            }
        }
    }

    // MARK: - Message Receiving
    /// Recursively listens for incoming WebSocket messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                // Handle different message types (binary data vs text)
                switch message {
                case .data(let data):
                    self?.handleReceivedData(data)  // Process binary data
                case .string(let text):
                    self?.handleReceivedText(text)  // Process text messages
                @unknown default:
                    break
                }
                // Continue listening for more messages (recursive call)
                self?.receiveMessage()

            case .failure(let error):
                print("Receive error: \(error)")
                // Update connection status on error
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionStatus = "Connection error"
                }
            }
        }
    }

    /// Processes received binary data by checking prefixes and data types
    /// - Parameter data: The binary data received from WebSocket
    private func handleReceivedData(_ data: Data) {
        // Check for audio data (prefixed with "AUDIO:")
        if let audioPrefix = "AUDIO:".data(using: .utf8), data.starts(with: audioPrefix) {
            let audioData = data.dropFirst(audioPrefix.count) // Remove prefix
            DispatchQueue.main.async {
                self.onAudioReceived?(audioData)
            }
            return
        }
        
        // Check for feedback data (prefixed with "FEEDBACK:")
        if let feedbackPrefix = "FEEDBACK:".data(using: .utf8), data.starts(with: feedbackPrefix) {
            let imageData = data.dropFirst(feedbackPrefix.count) // Remove prefix
            if let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.onFeedbackReceived?(image)
                }
            }
            return
        }

        // Try to decode as DrawingMessage JSON
        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }
        
        // Try to decode as text and handle as text message
        if let text = String(data: data, encoding: .utf8) {
            handleReceivedText(text)
            return
        }

        // Finally, try to decode as image data
        if let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.onImageReceived?(image)
            }
        }
    }
    
    /// Sends raw binary data without any processing or prefixes
    /// - Parameter data: Raw binary data to send
    func sendRawData(_ data: Data) {
        guard isConnected else { return } // Only send if connected
        webSocketTask?.send(.data(data)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    /// Convenience method to send a dictionary as JSON data
    /// - Parameter message: Dictionary to convert to JSON and send
    func sendChunkedMessage(_ message: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: message) {
            sendRawData(jsonData)
        }
    }

    /// Processes received text messages by parsing JSON and routing to appropriate handlers
    /// - Parameter text: The text message received from WebSocket
    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Try to decode as DrawingMessage first
        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }

        // Parse as generic JSON and handle based on message type
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            switch type {
            case "registered":
                // Confirmation that client registration was successful
                print("Successfully registered")

            case "status":
                // Server status update with connected user counts
                if let users = json["connectedUsers"] as? Int,
                   let aids = json["connectedAids"] as? Int {
                    DispatchQueue.main.async {
                        self.connectionStatus = "Users: \(users), Aids: \(aids)"
                    }
                }

            case "clear_drawings":
                // Command to clear all drawings on this device
                print("Received clear drawings command")
                DispatchQueue.main.async {
                    self.onClearDrawings?()
                }

            case "audio_command":
                // Audio control command (start/stop recording, etc.)
                if let commandRaw = json["command"] as? String,
                   let command = AudioCommand(rawValue: commandRaw) {
                    DispatchQueue.main.async {
                        self.onAudioCommandReceived?(command)
                    }
                }

            default:
                // Unknown message type - ignore
                break
            }
        }
    }
}

// MARK: - Audio Command Enum
/// Enum defining possible audio control commands that can be sent between devices
enum AudioCommand: String {
    case start = "audio_start"  // Start audio recording/transmission
    case end = "audio_end"      // Stop audio recording/transmission
}
