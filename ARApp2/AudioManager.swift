
import Foundation
import AVFoundation
import UIKit

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var inputNode: AVAudioInputNode?
    
    @Published var isMicMuted = false
    @Published var isSpeakerOn = true
    @Published var isCallActive = false
    
    private var sampleRate: Double = 16000  // will override with hardware sample rate
    
    private let bufferSize: AVAudioFrameCount = 1024
    
    var onAudioData: ((Data) -> Void)?
    
    private init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            
            // Activate session after setting preferred sample rate if needed
            try audioSession.setActive(true)
            
            sampleRate = audioSession.sampleRate
            print("Audio session sample rate: \(sampleRate)")
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        audioEngine.attach(playerNode)
        
        // Use the input node's hardware input format (important!)
        guard let inputNode = inputNode else {
            print("Audio input node unavailable")
            return
        }
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        sampleRate = inputFormat.sampleRate
        print("Input node format: \(inputFormat)")
        
        // Connect playerNode to main mixer with input hardware format for consistency
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: inputFormat)
        
        // Install tap on input node with correct input format
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isMicMuted else { return }
            
            if let data = self.audioBufferToData(buffer: buffer) {
                self.onAudioData?(data)
            }
        }
    }
    
    func startCall() {
        guard !isCallActive else { return }
        
        do {
            try audioEngine.start()
            playerNode.play()
            isCallActive = true
            print("Audio engine started")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func endCall() {
        guard isCallActive else { return }
        
        audioEngine.stop()
        playerNode.stop()
        isCallActive = false
        print("Audio engine stopped")
    }
    
    func toggleMic() {
        isMicMuted.toggle()
        print("Mic muted: \(isMicMuted)")
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if isSpeakerOn {
                try audioSession.overrideOutputAudioPort(.speaker)
            } else {
                try audioSession.overrideOutputAudioPort(.none)
            }
            print("Speaker toggled: \(isSpeakerOn)")
        } catch {
            print("Failed to toggle speaker: \(error)")
        }
    }
    
    func playAudioData(_ data: Data) {
        guard isCallActive else { return }
        
        if let buffer = dataToAudioBuffer(data: data) {
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
        }
    }
    
    private func audioBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: 1).map { channelDataValue[$0] }
        
        return Data(bytes: channelDataValueArray, count: channelDataValueArray.count * MemoryLayout<Float>.size)
    }
    
    private func dataToAudioBuffer(data: Data) -> AVAudioPCMBuffer? {
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        
        let frameCount = data.count / MemoryLayout<Float>.size
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        data.withUnsafeBytes { bytes in
            let floatPointer = bytes.bindMemory(to: Float.self)
            if let channelData = buffer.floatChannelData {
                channelData.pointee.assign(from: floatPointer.baseAddress!, count: frameCount)
            }
        }
        
        return buffer
    }
}
















