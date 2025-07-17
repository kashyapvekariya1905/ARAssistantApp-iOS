I'm building a full Swift-based iOS app that runs on **two real physical Apple devices**:

- ✅ iPad (as the **User**) — streams ARKit camera feed and receives 3D drawings
- ✅ iPhone 16 Pro Max (as the **Aid**) — views stream and draws on it in 3D

No virtual simulators are involved — both devices are physically connected over the same Wi-Fi or internet.

I’ve already implemented:
- Live AR camera stream from iPad to iPhone using a Node.js server and WebSockets
- 3D annotations from Aid that are placed correctly in AR using hit testing
- Perspective-aware preview, anchored drawing, proper shape retention, and consistent rendering
- Modular SwiftUI UI with navigation, brush tools, depth guides, and stroke control

---

Now I want you to add the **next module: real-time two-way audio calling** between User (iPad) and Aid (iPhone 16 Pro Max).

---

### 🔊 Audio Calling Requirements

1. **Only Native iOS APIs**
   - ✅ No WebRTC
   - ✅ No dependencies requiring GitHub URL or CocoaPods
   - ✅ Only use native Apple frameworks: `AVAudioEngine`, `AVAudioSession`, `AVAudioPlayerNode`, etc.

2. **Real-Time Two-Way Audio**
   - Both devices can speak and hear each other in real-time
   - Use `AVAudioEngine` for capturing and playback
   - Use existing WebSocket channel to transmit audio buffers (or a new socket if needed)
   - Delay must be minimal (under 300ms ideal)

3. **Must Integrate With Existing AR Session**
   - Do not interrupt or affect the live camera stream or 3D drawing features
   - Audio must continue running while AR is active
   - No freezing, black screens, or session restarts

4. **UX Features**
   - Mic mute/unmute button
   - Speakerphone toggle
   - “Hang up” button to end the audio session cleanly
   - Auto-start audio call as soon as both sides are connected

---

### 🛠 Code and Compatibility Constraints

- Use Swift 5+, SwiftUI, and ARKit
- Compatible with **iOS 15+**
- Runs on **Xcode 16+ on macOS Sequoia**
- All code must be clean, modular, and **error-free**
- Avoid any third-party SDKs that require GitHub URL or non-standard installation
- Integrate smoothly into the code I’ll provide in this conversation

---

### 📁 Required Swift Files

Split your solution across these files:

- `AudioManager.swift` → Manages audio session and engine
- `AudioSocketHandler.swift` → Handles sending/receiving audio buffers
- `CallControlsView.swift` → SwiftUI call controls (mic, speaker, hangup)
- Add integration hooks in `UserARView.swift` and `AidView.swift`

Now build **only this audio module** using the constraints and roles above.

Once this is stable, I’ll ask for future enhancements like audio recording or async fallback. For now, just focus on real-time voice communication between iPad (User) and iPhone 16 Pro Max (Aid) using sockets and native audio APIs.
