import Foundation
import UIKit

class SocketManager: ObservableObject {
    static let shared = SocketManager()

    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    @Published var isConnected = false
    @Published var connectionStatus = "Disconnected"

    var onImageReceived: ((UIImage) -> Void)?
    var onDrawingReceived: ((DrawingMessage) -> Void)?
    var onClearDrawings: (() -> Void)?
    var onAudioReceived: ((Data) -> Void)?
    var onAudioCommandReceived: ((AudioCommand) -> Void)?

    private init() {}

    func connect(as role: String, id: String = UUID().uuidString) {
        guard let url = URL(string: "ws://192.168.10.179:3000") else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

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
                } else {
                    print("Clear drawings sent successfully")
                }
            }
        }
    }

    func sendAudioData(_ audioData: Data) {
        guard isConnected else { return }

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

    func sendAudioCommand(_ command: AudioCommand) {
        guard isConnected else { return }

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
        if let audioPrefix = "AUDIO:".data(using: .utf8), data.starts(with: audioPrefix) {
            let audioData = data.dropFirst(audioPrefix.count)
            DispatchQueue.main.async {
                self.onAudioReceived?(audioData)
            }
            return
        }

        if let text = String(data: data, encoding: .utf8) {
            handleReceivedText(text)
            return
        }

        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }

        if let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.onImageReceived?(image)
            }
        }
    }

    private func handleReceivedText(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        if let drawingMessage = try? JSONDecoder().decode(DrawingMessage.self, from: data) {
            DispatchQueue.main.async {
                self.onDrawingReceived?(drawingMessage)
            }
            return
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
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

            case "clear_drawings":
                print("Received clear drawings command")
                DispatchQueue.main.async {
                    self.onClearDrawings?()
                }

            case "audio_command":
                if let commandRaw = json["command"] as? String,
                   let command = AudioCommand(rawValue: commandRaw) {
                    DispatchQueue.main.async {
                        self.onAudioCommandReceived?(command)
                    }
                }

            default:
                break
            }
        }
    }
}

enum AudioCommand: String {
    case start = "audio_start"
    case end = "audio_end"
}
