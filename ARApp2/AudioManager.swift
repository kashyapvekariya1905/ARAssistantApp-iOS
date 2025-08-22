//
//import Foundation
//import AVFoundation
//import UIKit
//
//class AudioManager: ObservableObject {
//    static let shared = AudioManager()
//    
//    private let audioEngine = AVAudioEngine()
//    private let playerNode = AVAudioPlayerNode()
//    private var inputNode: AVAudioInputNode?
//    
//    @Published var isMicMuted = false
//    @Published var isSpeakerOn = true
//    @Published var isCallActive = false
//    @Published var isCallOnHold = false
//    
//    private var sampleRate: Double = 48000
//    
//    private let bufferSize: AVAudioFrameCount = 512
//    
//    var onAudioData: ((Data) -> Void)?
//    
//    private init() {
//        setupAudioSession()
//        setupAudioEngine()
//    }
//    
//    private func setupAudioSession() {
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
//            try audioSession.setPreferredSampleRate(48000)
//            try audioSession.setPreferredIOBufferDuration(0.005)
//            try audioSession.overrideOutputAudioPort(.speaker)
//            try audioSession.setActive(true)
//            
//            sampleRate = audioSession.sampleRate
//            print("Audio session sample rate: \(sampleRate)")
//        } catch {
//            print("Failed to setup audio session: \(error)")
//        }
//    }
//    
//    private func setupAudioEngine() {
//        inputNode = audioEngine.inputNode
//        audioEngine.attach(playerNode)
//        
//        guard let inputNode = inputNode else {
//            print("Audio input node unavailable")
//            return
//        }
//        
//        let inputFormat = inputNode.inputFormat(forBus: 0)
//        sampleRate = inputFormat.sampleRate
//        print("Input node format: \(inputFormat)")
//        
//        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
//        
//        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
//        
//        audioEngine.mainMixerNode.outputVolume = 1.0
//        playerNode.volume = 1.0
//        
//        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
//            guard let self = self, !self.isMicMuted, self.isCallActive, !self.isCallOnHold else { return }
//            
//            if let data = self.audioBufferToData(buffer: buffer) {
//                self.onAudioData?(data)
//            }
//        }
//    }
//    
//    func startCall() {
//        guard !isCallActive else { return }
//        
//        do {
//            let audioSession = AVAudioSession.sharedInstance()
//            try audioSession.overrideOutputAudioPort(.speaker)
//            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//            
//            audioEngine.prepare()
//            try audioEngine.start()
//            playerNode.play()
//            isCallActive = true
//            isCallOnHold = false
//            print("Audio engine started with speaker output")
//        } catch {
//            print("Failed to start audio engine: \(error)")
//        }
//    }
//    
//    func endCall() {
//        guard isCallActive else { return }
//        
//        playerNode.stop()
//        audioEngine.stop()
//        isCallActive = false
//        isCallOnHold = false
//        print("Audio engine stopped")
//    }
//    
//    func toggleMic() {
//        isMicMuted.toggle()
//        print("Mic muted: \(isMicMuted)")
//    }
//    
//    func toggleSpeaker() {
//        isSpeakerOn.toggle()
//        
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            if isSpeakerOn {
//                try audioSession.overrideOutputAudioPort(.speaker)
//            } else {
//                try audioSession.overrideOutputAudioPort(.none)
//            }
//            print("Speaker toggled: \(isSpeakerOn)")
//        } catch {
//            print("Failed to toggle speaker: \(error)")
//        }
//    }
//    
//    func toggleHold() {
//        isCallOnHold.toggle()
//        
//        if isCallOnHold {
//            playerNode.pause()
//        } else {
//            playerNode.play()
//        }
//        
//        print("Call on hold: \(isCallOnHold)")
//    }
//    
//    func playAudioData(_ data: Data) {
//        guard isCallActive, !isCallOnHold else { return }
//        
//        if let buffer = dataToAudioBuffer(data: data) {
//            if let processedBuffer = amplifyAndProcessBuffer(buffer) {
//                playerNode.scheduleBuffer(processedBuffer, at: nil, options: .interrupts, completionHandler: nil)
//            }
//        }
//    }
//    
//    private func amplifyAndProcessBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
//        guard let channelData = buffer.floatChannelData else { return buffer }
//        
//        let frameLength = Int(buffer.frameLength)
//        let amplificationFactor: Float = 3.5
//        
//        for frame in 0..<frameLength {
//            let sample = channelData[0][frame]
//            let amplifiedSample = sample * amplificationFactor
//            channelData[0][frame] = max(-1.0, min(1.0, amplifiedSample))
//        }
//        
//        return buffer
//    }
//    
//    private func audioBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
//        guard let channelData = buffer.floatChannelData else { return nil }
//        
//        let channelDataValue = channelData.pointee
//        let frameLength = Int(buffer.frameLength)
//        
//        let amplificationFactor: Float = 2.0
//        var processedSamples = [Float]()
//        
//        for i in 0..<frameLength {
//            let sample = channelDataValue[i]
//            let amplifiedSample = max(-1.0, min(1.0, sample * amplificationFactor))
//            processedSamples.append(amplifiedSample)
//        }
//        
//        return Data(bytes: processedSamples, count: processedSamples.count * MemoryLayout<Float>.size)
//    }
//    
//    private func dataToAudioBuffer(data: Data) -> AVAudioPCMBuffer? {
//        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
//        
//        let frameCount = data.count / MemoryLayout<Float>.size
//        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
//        
//        buffer.frameLength = AVAudioFrameCount(frameCount)
//        
//        data.withUnsafeBytes { bytes in
//            let floatPointer = bytes.bindMemory(to: Float.self)
//            if let channelData = buffer.floatChannelData {
//                channelData.pointee.assign(from: floatPointer.baseAddress!, count: frameCount)
//            }
//        }
//        
//        return buffer
//    }
//}















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
    @Published var isCallOnHold = false
    
    private var sampleRate: Double = 48000
    private let bufferSize: AVAudioFrameCount = 512
    
    var onAudioData: ((Data) -> Void)?
    
    private init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord,
                                       mode: .voiceChat,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.overrideOutputAudioPort(.speaker)
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
        
        guard let inputNode = inputNode else {
            print("Audio input node unavailable")
            return
        }
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("Input format: \(inputFormat)")
        
        // Use the actual input format for processing
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                       sampleRate: sampleRate,
                                       channels: 1,
                                       interleaved: false)!
        
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: outputFormat)
        
        audioEngine.mainMixerNode.outputVolume = 1.0
        playerNode.volume = 1.0
        
        // Install tap with the input node's native format
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isMicMuted, self.isCallActive, !self.isCallOnHold else { return }
            
            if let data = self.audioBufferToData(buffer: buffer) {
                DispatchQueue.main.async {
                    self.onAudioData?(data)
                }
            }
        }
    }
    
    func startCall() {
        guard !isCallActive else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.overrideOutputAudioPort(.speaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()
            isCallActive = true
            isCallOnHold = false
            print("Audio engine started with speaker output")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func endCall() {
        guard isCallActive else { return }
        
        playerNode.stop()
        audioEngine.stop()
        isCallActive = false
        isCallOnHold = false
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
    
    func toggleHold() {
        isCallOnHold.toggle()
        
        if isCallOnHold {
            playerNode.pause()
        } else {
            playerNode.play()
        }
        
        print("Call on hold: \(isCallOnHold)")
    }
    
    func playAudioData(_ data: Data) {
        guard isCallActive, !isCallOnHold else { return }
        
        if let buffer = dataToAudioBuffer(data: data) {
            let processedBuffer = processIncomingAudio(buffer)
            playerNode.scheduleBuffer(processedBuffer, at: nil, options: [], completionHandler: nil)
        }
    }
    
    private func processIncomingAudio(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }
        
        let frameLength = Int(buffer.frameLength)
        let amplificationFactor: Float = 2.0 // Moderate amplification
        
        for frame in 0..<frameLength {
            let sample = channelData[0][frame]
            let amplifiedSample = sample * amplificationFactor
            channelData[0][frame] = max(-1.0, min(1.0, amplifiedSample))
        }
        
        return buffer
    }
    
    private func audioBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Handle both mono and stereo input, convert to mono
        var monoSamples = [Float]()
        monoSamples.reserveCapacity(frameLength)
        
        for frame in 0..<frameLength {
            var sample: Float = 0.0
            
            // Average all channels to create mono
            for channel in 0..<channelCount {
                sample += channelData[channel][frame]
            }
            sample /= Float(channelCount)
            
            // Apply moderate amplification
            let amplifiedSample = sample * 1.5
            let clampedSample = max(-1.0, min(1.0, amplifiedSample))
            monoSamples.append(clampedSample)
        }
        
        return Data(bytes: monoSamples, count: monoSamples.count * MemoryLayout<Float>.size)
    }
    
    private func dataToAudioBuffer(data: Data) -> AVAudioPCMBuffer? {
        let frameCount = data.count / MemoryLayout<Float>.size
        guard frameCount > 0 else { return nil }
        
        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: sampleRate,
                                      channels: 1,
                                      interleaved: false)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat,
                                          frameCapacity: AVAudioFrameCount(frameCount)) else {
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        data.withUnsafeBytes { bytes in
            guard let floatPointer = bytes.bindMemory(to: Float.self).baseAddress,
                  let channelData = buffer.floatChannelData else { return }
            
            channelData.pointee.assign(from: floatPointer, count: frameCount)
        }
        
        return buffer
    }
}
