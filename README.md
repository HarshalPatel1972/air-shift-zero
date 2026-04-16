# Air Shift

**Air Shift** is a gesture-driven, cross-platform file transfer engine designed for Android and Desktop (Windows, macOS, Linux). It eliminates the friction of traditional sharing by using cinematic hand gestures and secure point-to-point encryption.

## The Experience
1. **Shake**: Shake your phone to activate the frosted glass overlay.
2. **Grab**: Hover a single finger to select files, then make a **Fist** to "grab" them.
3. **Release**: Move to another device and open your **Palm**. The files "shift" instantly.

## Key Features
- **Cinema-Grade UX**: Frosted glass overlays, 3D hand cursors, and cellophane wrap animations.
- **Zero Cloud**: No accounts, no internet, and no tracking. Data stays on your local network.
- **TLS 1.3 Encryption**: Every session generates a unique, runtime-only certificate.
- **Integrity Verified**: Automatic SHA-256 checksums verify every byte on arrival.
- **Smart Routing**: Files are automatically categorized into Gallery, Documents, or Downloads based on MIME type.

## Technical Stack
- **Flutter**: Cross-platform UI.
- **MediaPipe (ML Kit)**: Real-time hand landmark gesture classification.
- **mDNS & BLE**: Peer discovery and proximity detection.
- **SecureSocket**: Encrypted P2P file streaming.

## Privacy Promise
- **Zero Persistence**: Session IDs and certificate thumbprints are regenerated every time you open the app.
- **No Analytics**: Not a single bit of metadata is ever sent to any external server.
- **Local Only**: If you aren't on the same network, Air Shift doesn't exist.

## Build Instructions

### Android
```bash
flutter build apk --release
```
*Note: Requires minSdkVersion 26 and CAMERA permission.*

### Desktop (Windows/macOS/Linux)
```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
```
*Note: Global hotkeys are `Ctrl+Alt+Space` on Windows/Linux and `Cmd+Option+Space` on macOS.*

---
Built with ❤️ by Air Shift Team.
