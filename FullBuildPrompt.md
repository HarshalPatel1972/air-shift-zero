# Air Shift — Full Build Prompt

> Give this entire document to your AI agent at the start of every session.
> The agent must read SKILL.md before writing a single line of code.

---

## What You Are Building

**Air Shift** is a gesture-driven, cross-platform file transfer app for Android and Desktop (Windows, macOS, Linux).

The core experience: a user shakes their phone (or presses a hotkey on desktop) to activate Air Shift. A frosted glass overlay appears over whatever app they are using. A 3D hand cursor tracks their hand via the front camera. The user hovers a single finger over files to select them (a shrinking circle confirms selection). When ready, they make a fist — all selected files turn green, confirming the grab. They then open their palm in front of another device running Air Shift. The moment the fist-to-palm transition is detected, the files transfer instantly over the local network via encrypted TCP. The receiving device shows a thin cellophane-wrapped paper that breathes while transferring, then peels open to reveal the file with a smart preview.

This is not just a file transfer app. It is a feeling — like physically handing something to another person.

**There is no cloud. No accounts. No pairing. No internet required. Zero data is ever stored or sent to any server.**

---

## First Step (Mandatory)

Before writing any code, read the SKILL.md file located at the root of this project. It contains:
- The full tech stack
- The complete design system (colors, motion, typography)
- The gesture state machine
- The transfer protocol
- The security rules
- The folder structure
- All 9 build phases with done-when conditions

Do not assume anything. If something is not in SKILL.md or this prompt, ask before proceeding.

---

## Project Setup

**Repository name:** `airshift`

**Platforms to configure:**
- Android (minSdkVersion 26, targetSdkVersion 34)
- Windows
- macOS
- Linux

**Flutter version:** Latest stable channel

**Run this to create the project:**
```bash
flutter create --org com.harshal.airshift --platforms android,windows,macos,linux airshift
```

**Package name:** `com.harshal.airshift`

**App name:** `Air Shift`

---

## The One Rule That Cannot Be Broken

The palm-open gesture ONLY fires a file transfer when it is preceded by a fist (HOLDING state). A user showing an open palm from IDLE or CURSOR state must be completely ignored. This is the single most important rule in the entire codebase. Every gesture detection path must enforce this.

```dart
// CORRECT
if (previousState == GestureState.holding && currentGesture == Gesture.openPalm) {
  fireTransfer();
}

// WRONG — never do this
if (currentGesture == Gesture.openPalm) {
  fireTransfer();
}
```

---

## Phase 1 — Foundation

**Goal:** Project skeleton with correct theme, routing, and session state machine stubs.

**Tasks:**

1. Create Flutter project with all 4 platforms configured.

2. Add all dependencies to `pubspec.yaml` exactly as listed in SKILL.md.

3. Create `lib/theme/colors.dart`:
```dart
import 'package:flutter/material.dart';

class AirShiftColors {
  static const bgBase = Color(0xFF0D0D0F);
  static const glassSurface = Color(0x0DFFFFFF);   // 5% white
  static const glassBorder = Color(0x26FFFFFF);     // 15% white
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8A8A9A);
  static const bluePrimary = Color(0xFF4A9EFF);
  static const greenConfirm = Color(0xFF3DFFA0);
  static const purpleActive = Color(0xFFA78BFA);
}
```

4. Create `lib/theme/motion.dart`:
```dart
class AirShiftMotion {
  static const overlayAppear = Duration(milliseconds: 180);
  static const selectionFill = Duration(milliseconds: 2000);
  static const grabConfirm = Duration(milliseconds: 150);
  static const paperUnwrap = Duration(milliseconds: 400);
  static const cursorMorph = Duration(milliseconds: 200);
}
```

5. Create `lib/session/session_state.dart`:
```dart
enum SessionState { idle, active, holding, transferring }
enum GestureState { idle, cursor, holding }
enum Gesture { none, singleFinger, fist, openPalm }
```

6. Create `lib/session/airshift_session.dart` as a stub with:
- `start()` — sets state to active, starts camera, BLE, mDNS
- `end()` — sets state to idle, EXPLICITLY stops camera, BLE, mDNS
- `onGestureEvent(GestureEvent event)` — state machine handler
- Session timeout logic based on file size tiers

7. Create `lib/app.dart` with MaterialApp, dark theme using `AirShiftColors.bgBase` as scaffold background.

8. Create `lib/main.dart` entry point.

**Done when:** `flutter build apk` and `flutter build windows` both succeed with zero errors. App launches showing a dark screen with correct background color.

---

## Phase 2 — Gesture Engine

**Goal:** MediaPipe hand detection working with correct state transitions.

**Tasks:**

1. Integrate `google_mlkit_pose_detection` (or the hand landmarks equivalent) for real-time hand landmark detection via front camera.

2. Create `lib/gesture/gesture_detector.dart`:
   - Opens front camera feed
   - Runs MediaPipe Hand Landmarker on each frame
   - Classifies gesture as: `none`, `singleFinger`, `fist`, `openPalm`
   - Emits `GestureEvent` stream
   - **Never saves any camera frame to disk or memory beyond processing**

3. Gesture classification logic:
   - `singleFinger`: index finger extended, all other fingers curled
   - `fist`: all fingers curled, including thumb
   - `openPalm`: all 5 fingers extended, palm facing camera
   - Use hand landmark angles/distances for classification, not pixel heuristics

4. Create `lib/gesture/gesture_state_machine.dart`:
```
IDLE
  → singleFinger detected → CURSOR
  → fist detected (no prior selection) → ignored

CURSOR
  → finger still within 10px radius for 2000ms → file SELECTED
  → fist detected → HOLDING (emit holdStart event)
  → openPalm detected → IGNORED (critical rule)

HOLDING
  → openPalm detected → emit transferTrigger (THIS is the only valid transfer trigger)
  → timeout → back to CURSOR, clear selection
```

5. Create `lib/gesture/hand_cursor.dart`:
   - CustomPainter rendering a 3D-style hand
   - Two states: open hand and closed fist
   - Smooth morph transition between states: 200ms ease-in-out
   - Drop shadow: `rgba(0,0,0,0.4)` offset 0 4px 12px
   - Positioned absolutely, follows hand landmark position in real time

6. Create `lib/gesture/selection_ring.dart`:
   - CustomPainter rendering a shrinking circle around hovered file
   - Starts at 100% size, shrinks to 0% over 2000ms
   - Jitter tolerance: if hand moves more than 10px, reset the timer
   - On complete: emit fileSelected event, ring snaps to solid outline

**Done when:** In debug mode, console logs correctly show `CURSOR → HOLDING → TRANSFER_TRIGGER` when performing the gesture sequence. Palm-only from idle logs `IGNORED`.

---

## Phase 3 — Overlay

**Goal:** Frosted glass overlay activates on shake, files are selectable via gesture.

**Tasks:**

1. Create `lib/overlay/overlay_manager.dart`:
   - Android: uses `SYSTEM_ALERT_WINDOW` to draw over other apps
   - Desktop: creates a frameless always-on-top window
   - `show()` and `hide()` methods
   - Overlay does NOT intercept touch events of underlying app (passthrough except for Air Shift's own UI elements)

2. Create `lib/overlay/overlay_widget.dart`:
   - Frosted glass panel: `BackdropFilter` with `ImageFilter.blur(sigmaX: 20, sigmaY: 20)`
   - Background: `AirShiftColors.glassSurface`
   - Border: 1px `AirShiftColors.glassBorder` with soft glow box-shadow in `AirShiftColors.bluePrimary` at 60% opacity
   - Contains: file grid + hand cursor + selection rings
   - Appear animation: opacity 0→1 + scale 0.97→1.0, 180ms ease-in-out

3. Create `lib/overlay/file_grid.dart`:
   - Shows files from current app context (via Android share intent detection) or falls back to recent files
   - Each file card: thumbnail + name + size
   - Hover state: blue outline (`AirShiftColors.bluePrimary`), 2px, rounded corners
   - Selected state: solid blue outline, stays visible
   - Grabbed state: all selected cards transition to `AirShiftColors.greenConfirm` outline simultaneously, 150ms

4. Connect gesture engine to overlay:
   - `singleFinger` position → moves hand cursor
   - `selectionRing` appears over file the cursor hovers
   - `fileSelected` event → file card gets blue outline
   - `holdStart` event → all selected cards flash green

**Done when:** Overlay appears on shake. Hand cursor follows gesture. Hovering a file for 2 seconds selects it with a blue outline. Making a fist turns all selected files green.

---

## Phase 4 — Discovery

**Goal:** Devices on the same network see each other via mDNS. BLE RSSI determines proximity.

**Tasks:**

1. Create `lib/discovery/mdns_service.dart`:
   - Service type: `_airshift._tcp`
   - On `AirShiftSession.start()`: announce device with:
     - Random session name (adjective + noun, e.g. "swift-ocean") — regenerated each session, never persisted
     - Local IP address
     - TCP port (default: 49317)
   - Browse for other `_airshift._tcp` devices continuously while session active
   - On `AirShiftSession.end()`: remove announcement immediately
   - Expose `Stream<List<AirShiftDevice>> nearbyDevices`

2. Create `lib/discovery/ble_proximity.dart`:
   - BLE scan starts only when gesture enters HOLDING state
   - Scans for other devices advertising Air Shift service UUID: `airshift-proximity-v1`
   - At palm-release moment: snapshot all RSSI values
   - Returns list of devices sorted by signal strength (strongest first)
   - Devices within 2 dB of each other = treat as equal proximity (broadcast to all)
   - BLE scan stops when session ends or transfer completes

3. `AirShiftDevice` model:
```dart
class AirShiftDevice {
  final String sessionName;     // "swift-ocean"
  final String ipAddress;
  final int port;
  final int? rssi;              // null if BLE not available
}
```

**Done when:** Two devices on the same WiFi network both appear in each other's `nearbyDevices` stream within 5 seconds of session start.

---

## Phase 5 — Transfer

**Goal:** Files transfer securely between two devices. Checksum verified on receive.

**Tasks:**

1. Create `lib/transfer/transfer_manifest.dart`:
```dart
class TransferManifest {
  final String token;           // UUID v4, one-time use
  final String fileName;
  final int fileSize;           // bytes
  final String mimeType;
  final String checksum;        // SHA-256 hex string of file bytes
}
```

2. Create `lib/transfer/checksum.dart`:
   - `Future<String> computeSHA256(File file)` — returns hex string
   - `Future<bool> verifySHA256(File file, String expected)` — returns bool
   - If verification fails: delete the received file immediately, emit error

3. Create `lib/transfer/transfer_server.dart`:
   - TCP server listening on port 49317
   - TLS 1.3 only — generate self-signed cert fresh each session
   - On incoming connection: read `TransferManifest` JSON
   - Emit `incomingTransfer` event with manifest
   - On user accept: stream file bytes to disk
   - On complete: verify SHA-256 checksum
   - If checksum fails: delete file, emit `transferFailed`
   - If checksum passes: emit `transferComplete` with saved file path
   - Session token: verify it has not been used before, mark used immediately

4. Create `lib/transfer/transfer_client.dart`:
   - Given target `AirShiftDevice`: open TCP connection
   - TLS 1.3 handshake
   - Send `TransferManifest` as JSON
   - Wait for ACK
   - Stream file bytes
   - Close connection immediately on complete
   - Session token: use once, discard

5. Timeout window by file size:
```dart
Duration transferTimeout(int fileSizeBytes) {
  if (fileSizeBytes < 10 * 1024 * 1024) return Duration(seconds: 10);
  if (fileSizeBytes < 1024 * 1024 * 1024) return Duration(seconds: 30);
  return Duration(seconds: 60);
}
```

6. Smart save defaults in `lib/transfer/save_location.dart`:
```dart
String resolveSavePath(String mimeType) {
  if (mimeType.startsWith('image/')) return galleryPath;
  if (mimeType.startsWith('video/')) return videosPath;
  if (mimeType.startsWith('audio/')) return musicPath;
  if (mimeType == 'application/vnd.android.package-archive') return downloadsPath;
  if (mimeType == 'application/pdf') return documentsPath;
  return downloadsPath;
}
```

**Done when:** A file sent from Device A arrives on Device B. SHA-256 checksum passes. File is saved to correct default location. A corrupted file is rejected and deleted automatically.

---

## Phase 6 — Receive UX

**Goal:** Full receive animation and smart preview working end-to-end.

**Tasks:**

1. Create `lib/receive/paper_animation.dart`:
   - Ultra-thin, near-transparent cellophane paper — no fold lines, no creases
   - Use CustomPainter with very low opacity fills and smooth bezier edges
   - State 1 (ARRIVING): paper appears instantly as a flat rectangle
   - State 2 (TRANSFERRING): breathing pulse — scale 1.0→1.02→1.0, 1.5s infinite, ease-in-out
   - State 3 (UNWRAPPING): clean peel-open from top-right corner, 400ms ease-out
   - State 4 (OPEN): file preview visible

2. Create `lib/receive/smart_preview.dart`:
   - Given `mimeType` and `filePath`, render correct preview:
   - `image/*` → `Image.file()` widget, full width
   - `video/*` → `video_player` package, autoplay muted, controls visible
   - `audio/*` → simple audio player UI, autoplay, show waveform placeholder
   - Everything else → file name + size + three buttons: Open, Save, Share

3. Create `lib/receive/receive_overlay.dart`:
   - Appears immediately when `incomingTransfer` event fires
   - Shows: sender session name, file name, file size
   - Paper animation plays in background
   - On `transferComplete`: trigger unwrap animation, show smart preview
   - On `transferFailed`: paper shakes (subtle translateX ±4px, 3 times), shows retry

4. Desktop (no camera) notification in `lib/notifications/airshift_notification.dart`:
   - NOT a system toast — Air Shift's own floating notification widget
   - Glass card style: same frosted glass aesthetic
   - Shows: sender name, file name, file size
   - Two buttons: `Receive` (`AirShiftColors.greenConfirm`) and `Decline` (subtle gray)
   - Auto-dismiss after 30 seconds
   - System tray icon pulses with blue glow when notification is active

5. "Start when detect" mode in `lib/session/airshift_session.dart`:
   - When enabled: listen for nearby BLE devices entering HOLDING state
   - On detection: silently activate camera + overlay on receiver
   - When disabled (default): show notification "Someone's holding a file — tap to enable camera"

**Done when:** Full receive flow works. Paper breathes during transfer. Unwraps cleanly on complete. Smart preview shows correct content. Desktop notification appears and works without camera.

---

## Phase 7 — Activation

**Goal:** All activation methods reliably start and end Air Shift sessions.

**Tasks:**

1. Create `lib/activation/shake_detector.dart` (Android):
   - Use `sensors_plus` accelerometer stream
   - Threshold: sustained acceleration > 15 m/s² for 2-3 seconds
   - Debounce: 500ms — prevent double-trigger
   - On detect: call `AirShiftSession.start()` if idle, `AirShiftSession.end()` if active
   - Stop listening when app is backgrounded without active session

2. Create `lib/activation/quick_tile_service.dart` (Android):
   - Implement Android Quick Settings Tile
   - Tile label: "Air Shift"
   - Tile icon: simple hand icon
   - On tap: toggle session (start if idle, end if active)
   - Tile state reflects session state (active = blue, idle = default)

3. Create `lib/activation/hotkey_service.dart` (Desktop):
   - Windows + Linux: register `Ctrl + Alt + Space` as global hotkey
   - macOS: register `Cmd + Option + Space` as global hotkey
   - On macOS: check if hotkey conflicts with Spotlight at startup, warn user in settings if so
   - On trigger: toggle session
   - Must work when app window is not focused (system tray / background)
   - Use `hotkey_manager` Flutter package or platform channel to native

**Done when:** Shake activates session on Android. Quick tile toggles session. Ctrl+Alt+Space toggles session on desktop while app is in background.

---

## Phase 8 — Settings + Permissions

**Goal:** All permissions properly explained. Settings persist. Glass UI matches spec.

**Tasks:**

1. Create `lib/settings/permission_explainer.dart`:
   - Full-screen explainer shown BEFORE each permission system prompt
   - One screen per permission group (camera, overlay, BLE, storage)
   - Plain language explanation of WHY the permission is needed
   - "Allow" button triggers system permission request
   - "Not now" defers (app still works with reduced functionality where possible)
   - Never request a permission silently without this explainer

2. Permission explainer content:
   - **Camera:** "Air Shift uses your front camera only during active sessions to detect hand gestures. No video is ever recorded, saved, or sent anywhere."
   - **Overlay:** "Air Shift needs to show a floating panel over your apps so you can grab files from anywhere. You can disable this for specific apps in your phone settings."
   - **Bluetooth:** "Air Shift uses Bluetooth signal strength to detect which nearby device you're closest to when you open your palm. No data is transmitted over Bluetooth."
   - **Storage:** "Air Shift needs access to your files so you can select and share them. We never read your files without your direct gesture action."

3. Create `lib/settings/settings_model.dart`:
```dart
class AirShiftSettings {
  String? customSavePath;           // null = use smart defaults
  bool startWhenDetect;             // default: false
  bool hapticFeedback;              // default: true
  // Persist via shared_preferences
}
```

4. Create `lib/settings/settings_screen.dart`:
   - Glass card sections: General, Privacy, Permissions, About
   - General: custom save path picker, haptic feedback toggle
   - Privacy: "Start when detect" toggle with explanation
   - Permissions: show status of each permission + tap to re-request
   - About: app version, "Zero cloud" badge, GitHub link
   - All toggles: Flutter `Switch` widget styled with `AirShiftColors.bluePrimary` active color
   - No drag sliders anywhere

**Done when:** First launch shows permission explainers before requesting. Settings persist across app restarts. All toggles work correctly.

---

## Phase 9 — Polish

**Goal:** Full end-to-end flow works flawlessly. All edge cases handled.

**Tasks:**

1. Haptic feedback:
   - Fist detected (grab): `HapticFeedback.mediumImpact()`
   - Palm opens (transfer fires): `HapticFeedback.heavyImpact()`
   - File selected (ring completes): `HapticFeedback.selectionClick()`
   - Android only — gracefully no-op on desktop

2. Edge cases to handle:
   - **Timeout with no receiver:** session returns to ACTIVE, subtle notification "No device caught it — try again"
   - **Checksum fail on receive:** file deleted, paper animation shows error shake, "Transfer failed — file may be corrupted"
   - **Multiple devices at equal RSSI:** broadcast to all within timeout window, all receive
   - **No camera on desktop:** skip gesture engine entirely, use notification-only receive flow
   - **Session interrupted mid-transfer:** clean up partial file, emit error
   - **App backgrounded during session:** keep session alive via ForegroundService (Android), system tray (desktop)
   - **BLE unavailable:** fall back to mDNS-only proximity (nearest mDNS device = target)
   - **Hotkey conflict on macOS:** detect at startup, show warning in settings, allow remapping

3. Final animation pass:
   - All transitions match timing specs in `AirShiftMotion`
   - No janky frames — profile with Flutter DevTools before final commit
   - Overlay glass effect smooth on Android (test on mid-range device, not just emulator)

4. Privacy audit (check every file):
   - Zero `http` or `https` calls to any external URL
   - Zero `print()` statements
   - Camera stream: confirm frames never written to disk
   - BLE: confirm scanner stopped in all code paths after session end
   - mDNS: confirm announcement removed in all code paths after session end

5. README.md:
   - What Air Shift is (2-3 sentences)
   - How to install (Android APK + desktop builds)
   - How to use (shake → grab → release)
   - Privacy promise
   - Build instructions: `flutter build apk --release` and `flutter build windows --release`

**Done when:** Full grab-to-release flow works between Android and desktop. All edge cases handled gracefully. Privacy audit passes. Zero external network calls in codebase.

---

## Critical Rules Summary (enforce in every phase)

1. Palm gesture from IDLE = ignored. Always.
2. Camera opened only in `AirShiftSession.start()`, closed only in `AirShiftSession.end()`.
3. BLE scanner started only in HOLDING state, stopped in `AirShiftSession.end()`.
4. mDNS announced in `start()`, removed in `end()`.
5. No external HTTP/HTTPS calls. Ever. Zero.
6. No `print()` in committed code.
7. No persistent device identity. Session name regenerated every session.
8. SHA-256 checksum verified on every received file. Fail = delete.
9. Session token used exactly once. Never persisted.
10. TLS 1.3 minimum. No fallback.
11. `flutter analyze` must pass with zero warnings before every commit.
12. One concern per commit. Conventional commit format.

---

## What NOT to Do

- Do not add any analytics library (Firebase, Sentry, Mixpanel, etc.)
- Do not add any cloud storage SDK
- Do not create any user account or authentication system
- Do not store any file transfer history
- Do not use FCM or any push notification service
- Do not add ads
- Do not add any feature not described in this prompt or SKILL.md
- Do not skip phases — complete phase N before starting phase N+1
- Do not break the grab→release gesture flow for any reason

---

## You Are Ready to Build

Read SKILL.md. Start Phase 1. Ask before assuming.
