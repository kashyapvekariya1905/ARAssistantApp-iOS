# AR Remote Assistance

An iOS application that enables real-time remote collaboration using Augmented Reality. This app allows two users to connect where one person (User) streams their real-world environment through their device's camera, while the other person (Assistant) can view the stream, draw 3D annotations, and provide guidance through two-way audio communication.

## Features

- **Role-Based Interface**: Separate views for "User" and "Assistant"
- **Real-Time Video Streaming**: Stream AR-enabled camera view between devices
- **3D AR Annotations**: Draw annotations that appear as 3D objects in the real world
- **Two-Way Audio Communication**: Integrated voice chat during sessions
- **WebSocket Networking**: Real-time data transmission for video, audio, and drawings

## Prerequisites

- **macOS** (for running Xcode)
- **Node.js** (for the WebSocket server)
- **Xcode** (for iOS app development)
- **Physical iOS device** (for full AR functionality)
- **iOS Simulator** (for testing the Assistant role)

## Installation & Setup

### Step 1: Download the Project

**Option A - Clone the repository:**
```bash
git clone [[YOUR_GIT_REPOSITORY_URL]](https://github.com/kashyapvekariya1905/ARAssistantApp-iOS)
cd AR-Remote-Assistance
```

**Option B - Download ZIP:**
1. Click the "Code" button on the GitHub repository
2. Select "Download ZIP"
3. Extract the downloaded file

### Step 2: Server Setup

#### Install Node.js
If you don't have Node.js installed, download and install it from [nodejs.org](https://nodejs.org/)

Or install via Homebrew:
```bash
brew install node
```

#### Setup and Run the Server
1. Navigate to the server directory:
```bash
cd server
```

2. Install dependencies:
```bash
npm install
```
or
```bash
npm i
```

3. Start the server:
```bash
npm start
```

The server should now be running and you'll see a confirmation message. Keep this terminal window open while using the app.

### Step 3: iOS Application Setup

#### Install Xcode
1. Download and install Xcode from the Mac App Store
2. Launch Xcode and accept the license agreement
3. Install additional components if prompted
4. Download iOS Simulator (Xcode should prompt you to install iOS simulators)

#### Open the Project
**Option A - Drag and Drop:**
1. Open Xcode
2. Drag the entire iOS app folder into Xcode

**Option B - Open via Xcode:**
1. Open Xcode
2. Select "Open a project or file"
3. Navigate to the iOS app folder and select the `.xcodeproj` file

#### Configure Network Settings
**Important:** You need to update the server connection URL in the code.

1. In Xcode, locate and open `SocketManager.swift`
2. Find this line:
```swift
guard let url = URL(string: "ws://localhost:3000") else { return }
```
3. Replace `localhost` with your Mac's IP address:
```swift
guard let url = URL(string: "ws://YOUR_MAC_IP_ADDRESS:3000") else { return }
```

**To find your Mac's IP address:**
- Open System Preferences > Network
- Select your active connection (Wi-Fi or Ethernet)
- Your IP address will be displayed (e.g., `192.168.1.100`)

### Step 4: Device Setup

#### Physical iPhone Setup (Required for User Role)
1. Connect your iPhone to your Mac via USB cable
2. Enable Developer Mode on your iPhone:
   - Go to Settings > Privacy & Security > Developer Mode
   - Toggle Developer Mode on
   - Restart your device when prompted
3. Trust your Mac:
   - When prompted on your iPhone, tap "Trust" and enter your passcode

#### Running on Physical Device
1. In Xcode, click on the device selector (top-left, next to the run button)
2. Select your connected iPhone from the list
3. Click the Run button (▶️) or press `Cmd + R`
4. If prompted about code signing:
   - Select your Apple ID team
   - Xcode will handle provisioning automatically
5. On first run, you may need to trust the developer certificate:
   - Go to iPhone Settings > General > VPN & Device Management
   - Find your developer app and tap "Trust"
   - Return to Xcode and run again

#### Running on Simulator (For Assistant Role)
1. In Xcode, click on the device selector
2. Choose an iOS Simulator (e.g., "iPhone 15 Pro")
3. Click the Run button (▶️) or press `Cmd + R`

## Usage

### Running Both Roles Simultaneously
1. **First Device (Physical iPhone - User):**
   - Select your iPhone from device list in Xcode
   - Run the app (`Cmd + R`)
   - Choose "User" role in the app

2. **Second Device (Simulator - Assistant):**
   - Select a simulator from device list in Xcode
   - Run the app again (`Cmd + R`)
   - Choose "Assistant" role in the app

### App Workflow
1. Both devices connect to the server
2. User taps "Start Streaming" to share their camera view
3. Assistant receives the video stream and can draw annotations
4. Drawings appear as 3D objects in the User's AR environment
5. Both users can communicate via audio throughout the session

## Troubleshooting

### Build Issues
If you encounter build problems:
```bash
# Clean the workspace
Cmd + Shift + K

# Rebuild the project
Cmd + B

# Run the project
Cmd + R
```

### Common Issues

**Server Connection Failed:**
- Ensure the server is running (`npm start` in the server directory)
- Verify the IP address in `SocketManager.swift` is correct
- Make sure both devices are on the same network

**App Won't Install on Device:**
- Check that Developer Mode is enabled on your iPhone
- Verify the developer certificate is trusted in iPhone settings
- Try disconnecting and reconnecting the USB cable

**Camera/AR Not Working:**
- AR features require a physical iOS device
- Ensure camera permissions are granted when prompted
- Test on a device that supports ARKit (iPhone 6s or newer)

**Audio Issues:**
- Grant microphone permissions when prompted
- Check device volume settings
- Ensure devices are not muted

### Dependencies
The project should include all necessary dependencies. If you encounter missing dependencies:
1. Check if there are any `.xcworkspace` files (indicating CocoaPods usage)
2. If present, install CocoaPods and run `pod install`
3. Open the `.xcworkspace` file instead of `.xcodeproj`

## System Requirements

- **iOS**: 13.0 or later
- **Xcode**: 12.0 or later
- **macOS**: 10.15 or later
- **Node.js**: 14.0 or later
- **Physical iOS Device**: Required for User role (AR functionality)

## Project Structure
```
.
├── AidDrawingView.swift
├── ARApp2.entitlements
├── ARApp2App.swift
├── Assets.xcassets
│   ├── AccentColor.colorset
│   │   └── Contents.json
│   ├── AppIcon.appiconset
│   │   ├── Contents.json
│   │   ├── Untitled design 1.png
│   │   ├── Untitled design 2.png
│   │   └── Untitled design.png
│   └── Contents.json
├── AudioManager.swift
├── AudioSocketHandler.swift
├── CallControlsView.swift
├── CameraStreamManager.swift
├── ContentView.swift
├── DrawingManager.swift
├── DrawingModel.swift
├── Info.plist
├── SocketManager.swift
└── UserARView.swift
```


## Support

If you encounter any issues or have questions, please [create an issue](link-to-your-issues-page) on the GitHub repository.
