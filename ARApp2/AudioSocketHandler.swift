
import Foundation

class AudioSocketHandler: ObservableObject {
    static let shared = AudioSocketHandler()

    private let socketManager = SocketManager.shared
    private let audioManager = AudioManager.shared

    // Callback from view for receiving commands
    var onAudioControlReceived: ((String) -> Void)?

    private init() {
        setupAudioHandlers()
    }

    private func setupAudioHandlers() {
        audioManager.onAudioData = { [weak self] data in
            self?.sendAudioData(data)
        }

        socketManager.onAudioReceived = { [weak self] data in
            self?.audioManager.playAudioData(data)
        }

        socketManager.onAudioCommandReceived = { [weak self] command in
            switch command {
            case .start:
                self?.onAudioControlReceived?("start")
            case .end:
                self?.onAudioControlReceived?("end")
            }
        }
    }

    func startAudioCall() {
        audioManager.startCall()
        socketManager.sendAudioCommand(.start)
    }

    func endAudioCall() {
        audioManager.endCall()
        socketManager.sendAudioCommand(.end)
    }

    private func sendAudioData(_ data: Data) {
        socketManager.sendAudioData(data)
    }
}

