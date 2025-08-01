
import SwiftUI

struct CallControlsView: View {
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var audioSocketHandler = AudioSocketHandler.shared
    
    var body: some View {
        HStack(spacing: 24) {
            Button(action: {
                audioManager.toggleMic()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: audioManager.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 24))
                    Text(audioManager.isMicMuted ? "Unmute" : "Mute")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(audioManager.isMicMuted ? Color.red : Color.gray.opacity(0.6))
                .clipShape(Circle())
            }
            
            Button(action: {
                audioSocketHandler.endAudioCall()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                    Text("End")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.red)
                .clipShape(Circle())
            }
            
            Button(action: {
                audioManager.toggleSpeaker()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: audioManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill")
                        .font(.system(size: 24))
                    Text("Speaker")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(audioManager.isSpeakerOn ? Color.blue : Color.gray.opacity(0.6))
                .clipShape(Circle())
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
}


