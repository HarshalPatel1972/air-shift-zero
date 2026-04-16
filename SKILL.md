---
name: airshift
description: Build Air Shift — a gesture-driven, cross-platform file transfer app for Android and Desktop. Use this skill for all tasks related to the airshift repository.
---

# Air Shift Skill

Air Shift is a Flutter-based cross-platform app (Android + Windows + macOS + Linux) that lets users transfer files between devices using natural hand gestures — grab a file with a fist, release it with an open palm near another device. No cloud. No accounts. No pairing. Pure P2P over local network.

---

## Core Principles

- **Zero cloud.** No servers, no analytics, no telemetry, no user data ever leaves the device or gets stored anywhere.
- **Gesture is the UX.** Every product decision must preserve the grab→release flow. Never suggest alternatives that break this.
- **Camera is not always on.** Camera activates only during an active Air Shift session. Must be explicitly released on session end or timeout.
- **Atomic commits.** Every commit is one logical unit. Conventional commit format: `type(scope): message`. Types: feat, fix, chore, style, docs, refactor. Never group concerns.
- **Phase-gated.** Never start phase N+1 until phase N passes its done-when condition.
- **Free tier only.** No paid services, no credit card required infrastructure.

---

## Tech Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (latest stable), Dart |
| Gesture/ML | MediaPipe Hand Landmarker (on-device, Google) |
| Device Discovery | mDNS (multicast DNS, Zeroconf) |
| Proximity Detection | BLE RSSI |
| File Transfer | Direct TCP + TLS 1.3 |
| Native Performance Layer | Rust FFI (optional, transfer engine only) |
| Android Overlay | SYSTEM_ALERT_WINDOW permission |
| Android Activation | Quick Settings Tile + Shake detection |
| Desktop Activation | Global hotkey: Ctrl+Alt+Space (Windows/Linux), Cmd+Option+Space (macOS) |
| Haptics | Android Vibrator API (HapticFeedback in Flutter) |
| Notifications | flutter_local_notifications (no FCM, no cloud) |

---

## Design System

**Palette:**
```
--bg-base:        #0D0D0F
--glass-surface:  rgba(255, 255, 255, 0.05)
--glass-border:   rgba(255, 255, 255, 0.15)
--text-primary:   #FFFFFF
--text-secondary: #8A8A9A
--blue-primary:   #4A9EFF   (hover cursor + selected state)
--green-confirm:  #3DFFA0   (grab confirmed + all selected files)
--purple-active:  #A78BFA   (active transfer in progress)
```

**Overlay:**
- Frosted glass panel, ~70% transparent
- Border glow: `--blue-primary` at 60% opacity, 1px border, soft box-shadow
- Feels barely there — not intrusive

**3D Hand Cursor:**
- Two states: open hand (browsing) and closed fist (grabbed)
- Smooth morph animation between states, 200ms ease-in-out
- Subtle drop shadow: `rgba(0,0,0,0.4)` offset 0 4px 12px
- Rendered as Flutter CustomPainter or Lottie animation

**File Selection Visuals:**
- Cursor hovering a file: animated `--blue-primary` outline, shrinking circle fills over 2 seconds (jitter tolerance: 10px radius)
- File selected: solid `--blue-primary` outline stays
- Multiple selected: each has its own solid blue outline
- On fist grab: ALL selected outlines transition to `--green-confirm` simultaneously, 150ms

**Receive Animation (Wrapped Paper):**
- Ultra-thin, near-transparent cellophane/plastic paper — no fold lines, no creases
- Arrives instantly as placeholder
- Breathing pulse animation (subtle scale 1.0→1.02→1.0, 1.5s infinite) while transfer in progress
- On 100% complete: clean peel-open animation, 400ms ease-out — no dramatic unwrap
- File preview appears immediately after unwrap

**Smart Preview after receive:**
| File type | Behavior |
|---|---|
| Image | Shows inline full preview |
| Video | Inline player, autoplay muted |
| Audio | Inline player, autoplay |
| APK / other | Options: Open / Save / Share |

**Settings Screen:**
- Glass cards per section
- Flutter Switch widgets (proper toggles, no drag sliders)
- Clean section headers, minimal icons
- Same frosted glass aesthetic as overlay

**Typography:**
- Font: Inter or system default
- Body: 14px, weight 400
- Emphasis: 16px, weight 500
- Labels: 12px, weight 400, `--text-secondary`
- Never use weight 700+

**Motion rules:**
- All transitions: ease-in-out, never linear
- Overlay appear: opacity 0→1 + scale 0.97→1.0, 180ms
- Selection circle fill: 2000ms, cancelable on move
- Grab confirmation (blue→green): 150ms simultaneous
- Paper unwrap: 400ms ease-out
- Haptic on grab: `HapticFeedback.mediumImpact()`
- Haptic on release/transfer fire: `HapticFeedback.heavyImpact()`

---

## Gesture State Machine

```
IDLE
  └─ [session activated: shake / quick tile / hotkey]
       → ACTIVE (camera on, overlay visible, BLE scanning, mDNS broadcasting)

ACTIVE
  └─ [single finger detected] → CURSOR mode (browsing/selecting files)
       └─ [finger still for 2s on file] → file SELECTED (blue outline)
       └─ [repeat for more files] → MULTI-SELECT
  └─ [fist detected] → HOLDING (all selected files turn green, BLE RSSI snapshot)
       └─ [palm detected — MUST be fist→palm transition, not palm from idle]
            → TRANSFER FIRES to nearest device(s) within timeout window
       └─ [palm detected with no prior fist] → IGNORED
       └─ [timeout expires] → back to ACTIVE, selection cleared

TRANSFER
  └─ [in progress] → paper animation breathing on receiver
  └─ [complete] → paper unwraps, smart preview shown
  └─ [failed] → subtle error state, retry option

SESSION END
  └─ [shake again / toggle off / inactivity timeout]
       → camera EXPLICITLY released
       → BLE scanner EXPLICITLY stopped
       → mDNS broadcasting stopped
       → overlay dismissed
       → back to IDLE
```

**Critical rule:** The palm-open gesture ONLY fires transfer when preceded by a fist (HOLDING state). A palm shown from IDLE or CURSOR state is completely ignored. This is non-negotiable — it prevents misfires.

---

## Activation Methods

**Android:**
- Shake device for 2-3 seconds (use accelerometer threshold: >15 m/s² sustained)
- Quick Settings tile tap
- Both must call the same `AirShiftSession.start()` method

**Desktop (Windows / Linux):**
- Global hotkey: `Ctrl + Alt + Space`
- Must work even when app is in background / system tray

**Desktop (macOS):**
- Global hotkey: `Cmd + Option + Space`
- Check for Spotlight conflict at runtime, warn user if detected

---

## Discovery & Targeting

**mDNS (device discovery):**
- Service name: `_airshift._tcp.local`
- Each device announces: device name (random, session-scoped), IP, port
- Device name is temporary — regenerated each session, never persisted
- On session end: mDNS announcement removed immediately

**BLE RSSI (proximity at release):**
- Scan only during HOLDING state (after fist detected)
- At palm-open moment: snapshot RSSI of all nearby Air Shift devices
- Strongest RSSI = target device(s)
- If multiple devices within 2 dB of each other = broadcast to all of them
- Timeout window for broadcast = relative to file size:
  - < 10MB → 10 seconds
  - 10MB–1GB → 30 seconds
  - > 1GB → 60 seconds
- Within timeout: ANY device that shows open palm receives the file

---

## Transfer Protocol

**Handshake:**
1. Sender generates one-time session token (UUID v4) on fist detection
2. At palm release: sender opens TCP connection to target IP:port (from mDNS)
3. TLS 1.3 handshake
4. Sender sends: `{ token, fileName, fileSize, mimeType, checksum: SHA-256 }`
5. Receiver shows incoming notification / overlay
6. On accept: ACK sent, transfer begins
7. On complete: receiver verifies SHA-256 checksum
8. Session token expires immediately after transfer

**Security rules (enforce in code):**
- TLS 1.3 minimum, no fallback to older versions
- Certificate pinning per session (self-signed cert generated fresh each session)
- One-time session token — never reused
- SHA-256 checksum verification on every received file
- If checksum fails: file deleted, error shown, never opened
- No persistent connections between devices
- No device identity stored on disk

---

## Receiving — No Camera Desktop

When a desktop has no camera (or camera not enabled):
- Detects incoming transfer via mDNS + TCP knock
- Air Shift system tray icon pulses with `--blue-primary` glow
- Air Shift's own premium notification appears (NOT a system toast):
  - Shows: sender device name, file name, file size
  - Two buttons: **Receive** (green) / **Decline** (subtle gray)
  - Auto-dismisses after 30 seconds if no response

---

## Receiving — "Start When Detect" Mode

**Mode ON (user opted in):**
- Nearby device enters HOLDING state → receiver's Air Shift detects via BLE
- Camera activates silently on receiver
- Overlay appears, hand cursor ready
- User just opens palm → receives

**Mode OFF (default):**
- Notification: "Someone's holding a file — tap to enable camera"
- User taps → camera on → ready to receive

---

## File Source Rules

- Air Shift can only transfer files that the underlying OS/app exposes via standard share intent
- If a file in WhatsApp is not yet downloaded: the 2-second hover triggers download first, THEN makes it grabbable
- Air Shift never reads app-private storage directly
- Air Shift never captures screen content of underlying apps
- Overlay is purely visual — it does not intercept touch events of underlying apps except when Air Shift session is active

---

## Smart Save Defaults

| MIME type | Save location |
|---|---|
| image/* | Gallery / Photos |
| video/* | Gallery / Videos |
| audio/* | Music folder |
| application/vnd.android.package-archive | Downloads |
| application/pdf | Documents |
| Everything else | Downloads |

If user has specified a custom save location in Settings → always use that instead.

---

## Privacy Rules (enforce strictly in code)

- Camera: opened only in `AirShiftSession.start()`, closed in `AirShiftSession.end()` — never anywhere else
- No frame from camera is ever saved to disk, sent over network, or logged
- BLE: scanner started in `AirShiftSession.start()`, stopped in `AirShiftSession.end()`
- mDNS: announced in `AirShiftSession.start()`, removed in `AirShiftSession.end()`
- No analytics, no crash reporting, no telemetry calls anywhere in codebase
- No user accounts, no sign-in, no persistent device ID
- Device name is randomly generated per session, never written to disk
- No `SharedPreferences` or local DB for anything except user's own settings (save location, "start when detect" toggle, etc.)

---

## Permissions (Android)

| Permission | Why |
|---|---|
| `CAMERA` | Gesture detection via front camera |
| `SYSTEM_ALERT_WINDOW` | Overlay over other apps |
| `FOREGROUND_SERVICE` | Keep session alive while using other apps |
| `ACCESS_FINE_LOCATION` | Required by Android for BLE scanning |
| `BLUETOOTH_SCAN` | BLE device discovery |
| `BLUETOOTH_CONNECT` | BLE RSSI reading |
| `CHANGE_NETWORK_STATE` | mDNS on local network |
| `VIBRATE` | Haptic feedback |
| `READ_EXTERNAL_STORAGE` / `READ_MEDIA_*` | Access files for sharing |

Every permission must have a clear in-app explanation screen shown before the system prompt. Never request permissions without explaining why in plain language.

---

## Folder Structure

```
airshift/
├── lib/
│   ├── main.dart
│   ├── app.dart                        root widget, theme, routing
│   ├── session/
│   │   ├── airshift_session.dart       start(), end(), state machine
│   │   ├── session_token.dart          UUID v4 one-time token generator
│   │   └── session_state.dart          IDLE / ACTIVE / HOLDING / TRANSFER enum
│   ├── gesture/
│   │   ├── gesture_detector.dart       MediaPipe wrapper, emits GestureEvent
│   │   ├── gesture_state.dart          IDLE / CURSOR / HOLDING enum
│   │   ├── hand_cursor.dart            3D hand CustomPainter (open / fist states)
│   │   └── selection_ring.dart         shrinking circle CustomPainter
│   ├── discovery/
│   │   ├── mdns_service.dart           announce + browse _airshift._tcp.local
│   │   └── ble_proximity.dart          RSSI scan + snapshot at palm release
│   ├── transfer/
│   │   ├── transfer_server.dart        TCP listener, TLS 1.3, receive files
│   │   ├── transfer_client.dart        TCP sender, TLS 1.3, send files
│   │   ├── transfer_manifest.dart      { token, fileName, fileSize, mimeType, checksum }
│   │   └── checksum.dart               SHA-256 verify
│   ├── overlay/
│   │   ├── overlay_manager.dart        SYSTEM_ALERT_WINDOW controller (Android)
│   │   ├── overlay_widget.dart         frosted glass overlay root widget
│   │   └── file_grid.dart              file browser inside overlay
│   ├── receive/
│   │   ├── receive_overlay.dart        wrapped paper animation + smart preview
│   │   ├── paper_animation.dart        cellophane wrap CustomPainter + unwrap
│   │   └── smart_preview.dart          image / video / audio / other router
│   ├── activation/
│   │   ├── shake_detector.dart         accelerometer >15 m/s² for 2-3s
│   │   ├── quick_tile_service.dart     Android Quick Settings tile
│   │   └── hotkey_service.dart         Ctrl+Alt+Space global hotkey (desktop)
│   ├── notifications/
│   │   └── airshift_notification.dart  premium in-app notification (no FCM)
│   ├── settings/
│   │   ├── settings_screen.dart        glass card UI
│   │   ├── settings_model.dart         save location, start-when-detect, etc.
│   │   └── permission_explainer.dart   per-permission explanation screen
│   └── theme/
│       ├── colors.dart                 all color constants
│       ├── typography.dart             text styles
│       └── motion.dart                 duration + curve constants
├── android/
├── windows/
├── macos/
├── linux/
├── assets/
│   └── hand/                           hand cursor assets / Lottie JSON
├── pubspec.yaml
└── README.md
```

---

## Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  google_mlkit_pose_detection: ^0.10.0   # MediaPipe hand landmarks
  nsd: ^4.0.0                             # mDNS discovery
  flutter_blue_plus: ^1.31.0             # BLE RSSI
  flutter_local_notifications: ^17.0.0   # local notifications, no FCM
  sensors_plus: ^5.0.0                   # accelerometer for shake
  permission_handler: ^11.0.0            # runtime permissions
  path_provider: ^2.1.0                  # save location defaults
  crypto: ^3.0.3                         # SHA-256 checksum
  uuid: ^4.0.0                           # one-time session tokens
  lottie: ^3.0.0                         # hand cursor animation
```

---

## Commit Conventions

```
type(scope): short imperative message
```

Allowed types: `feat` `fix` `chore` `style` `docs` `refactor`
Max 72 chars. Lowercase. No period. Imperative mood.

Examples:
- `feat(gesture): implement fist-to-palm transition detection`
- `feat(transfer): add TLS 1.3 + SHA-256 verification`
- `fix(overlay): release camera on session timeout`
- `chore(deps): add flutter_blue_plus for BLE RSSI`

**Never:**
- Group multiple concerns in one commit
- Write "wip", "updates", "fix stuff"
- Commit without running `flutter analyze` first

---

## Quality Gates (before each phase commit)

- `flutter analyze` → zero errors, zero warnings
- `flutter build apk` → clean build
- Camera is never accessed outside `AirShiftSession.start()`
- BLE scanner is never left running after `AirShiftSession.end()`
- No hardcoded IPs, ports, or device identifiers
- No `print()` statements in committed code
- No network calls to any external server anywhere in codebase
- Checksum verification present on every file receive path
- Session token used exactly once and never persisted

---

## Build Phases

**Phase 1 — Foundation**
- Flutter project setup, all platforms configured
- Theme, colors, typography implemented
- `AirShiftSession` state machine (stub methods)
- Done when: app builds on Android + Windows with correct theme

**Phase 2 — Gesture Engine**
- MediaPipe Hand Landmarker integrated
- Fist / open palm / single finger detection
- Fist→palm transition logic (palm from idle = ignored)
- 3D hand cursor rendered over camera feed
- Done when: gesture states log correctly in debug, cursor follows hand

**Phase 3 — Overlay**
- SYSTEM_ALERT_WINDOW overlay (Android)
- Desktop window overlay
- Frosted glass UI, file browser inside overlay
- Selection ring (shrinking circle, jitter tolerance)
- Blue outline on select, green on grab
- Done when: overlay activates on shake, files selectable by hover

**Phase 4 — Discovery**
- mDNS announce + browse
- BLE RSSI scan during HOLDING state
- Device list visible in debug
- Done when: two devices on same network see each other

**Phase 5 — Transfer**
- TCP server + client
- TLS 1.3 handshake
- One-time session token
- SHA-256 checksum
- Smart save defaults
- Done when: file transfers successfully between two devices, checksum passes

**Phase 6 — Receive UX**
- Wrapped paper animation
- Smart preview (image / video / audio / other)
- Desktop premium notification
- "Start when detect" mode
- Done when: full receive flow works end-to-end with animations

**Phase 7 — Activation**
- Shake detection (Android)
- Quick Settings tile (Android)
- Global hotkey Ctrl+Alt+Space (Desktop)
- Done when: all three activation paths start a session correctly

**Phase 8 — Settings + Permissions**
- Permission explainer screens
- Settings screen (glass UI, proper toggles)
- Save location picker
- "Start when detect" toggle
- Done when: all permissions explained, settings persist correctly

**Phase 9 — Polish**
- Haptic feedback on grab + release
- All animations at spec
- Edge cases: timeout, checksum fail, no camera desktop, multi-device broadcast
- Done when: full user flow works without any bugs end-to-end
