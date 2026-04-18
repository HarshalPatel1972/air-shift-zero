import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';

import 'gesture/hand_cursor.dart';
import 'gesture/selection_ring.dart';
import 'gesture/gesture_indicator.dart';
import 'session/airshift_session.dart';
import 'session/session_state.dart' as session_state;
import 'session/session_state.dart';
import 'overlay/overlay_manager.dart';
import 'activation/shake_detector.dart';

import 'settings/settings_screen.dart';
import 'settings/permission_explainer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:screenshot/screenshot.dart';
import 'session/airshift_session.dart';
import 'transfer/screenshot_service.dart';

class AirShiftApp extends StatefulWidget {
  const AirShiftApp({super.key});

  @override
  State<AirShiftApp> createState() => _AirShiftAppState();
}

class _AirShiftAppState extends State<AirShiftApp> {
  final _session = AirShiftSession.instance;
  late AirShiftShakeDetector _shakeDetector;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      _shakeDetector = AirShiftShakeDetector(session: _session);
      _shakeDetector.start();
    }
    
    // Ensure the UI is rendered before checking permissions to avoid startup deadlock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _checkInitialPermissions();
      }
    });
  }

  Future<void> _checkInitialPermissions() async {
    // Phase 11 - Active Permission Wizard
    if (defaultTargetPlatform != TargetPlatform.android) return;
    
    // 1. Camera - Required for Hand Tracking
    if (!(await Permission.camera.isGranted)) {
      await Permission.camera.request();
    }

    // 2. Overlay - Required for Shake Activation
    if (!(await FlutterOverlayWindow.isPermissionGranted())) {
      await FlutterOverlayWindow.requestPermission();
    }

    // 3. Location/Nearby - Required for P2P Discovery
    if (!(await Permission.location.isGranted)) {
      await Permission.location.request();
    }
  }

  @override
  void dispose() {
    _session.dispose();
    _shakeDetector.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Shift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AirShiftColors.bgBase,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: AirShiftTypography.body,
          headlineMedium: AirShiftTypography.emphasis,
          labelSmall: AirShiftTypography.label,
        ),
      ),
      routes: {
        '/': (context) => FoundationScreen(session: _session),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

class FoundationScreen extends StatefulWidget {
  final AirShiftSession session;
  const FoundationScreen({super.key, required this.session});

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> with SingleTickerProviderStateMixin {
  Offset _cursorPos = Offset.zero;
  bool _isFist = false;
  SessionState _sState = SessionState.idle;
  session_state.Gesture _currentGesture = session_state.Gesture.none;
  String _gestureName = "None";
  
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _flashAnimation = CurvedAnimation(parent: _flashController, curve: Curves.easeIn);

    widget.session.detector.gestureStream.listen((event) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _cursorPos = Offset(event.x * size.width, event.y * size.height);
          _isFist = (event.gesture == session_state.Gesture.fist);
          _currentGesture = event.gesture;
          _gestureName = event.gestureName;
        });
      }
    });
    
    widget.session.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _sState = state;
        });
      }
    });

    widget.session.screenshotEvent.listen((path) {
      if (mounted) {
        _triggerFlash();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AirShiftColors.greenConfirm,
            content: Text('Captured! Saved to AirShift/Screenshots', style: const TextStyle(fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    });
  }

  void _triggerFlash() {
    _flashController.forward().then((_) => _flashController.reverse());
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: AirShiftScreenshotService.instance.screenshotController,
      child: Scaffold(
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AirShiftColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.airplanemode_active,
                  color: AirShiftColors.bluePrimary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Air Shift',
                  style: AirShiftTypography.emphasis.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  _sState == SessionState.idle ? 'Press "Start" to Test Gestures' : 'Gesture Engine Active',
                  style: AirShiftTypography.label,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sState == SessionState.idle ? AirShiftColors.bluePrimary : Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    shadowColor: AirShiftColors.bluePrimary.withOpacity(0.4),
                  ),
                  onPressed: () async {
                    if (_sState == SessionState.idle) {
                      final status = await Permission.camera.request();
                      if (status.isGranted) {
                        widget.session.start();
                      } else {
                        if (mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Camera access is required for hand tracking'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    } else {
                      widget.session.end();
                    }
                  },
                  child: Text(
                    _sState == SessionState.idle ? 'Start Session' : 'Stop Engine',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (_sState != SessionState.idle) ...[
            // Gesture indicator at the top
            Positioned(
              top: MediaQuery.of(context).padding.top + 40,
              left: 20,
              right: 20,
              child: Center(
                child: GestureIndicator(
                  gesture: _currentGesture,
                  gestureName: _gestureName,
                ),
              ),
            ),
            
            HandCursor(
              isFist: _isFist,
              x: _cursorPos.dx,
              y: _cursorPos.dy,
            ),
          ],
          if (_sState != SessionState.idle && !_isFist)
            SelectionRing(
              position: _cursorPos,
              onComplete: () {
                debugPrint('Selection Completed!');
              },
            ),

          // Persistent Camera feed for instant engine activation
          Positioned(
            bottom: 20,
            right: 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _sState == SessionState.idle ? 0.0 : 1.0,
              child: Container(
                width: 160,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AirShiftColors.bluePrimary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: defaultTargetPlatform == TargetPlatform.windows
                      ? (widget.session.detector.webviewController != null
                          ? Webview(
                              widget.session.detector.webviewController!,
                              permissionRequested: (url, kind, isUserInitiated) async {
                                if (kind == WebviewPermissionKind.camera) {
                                  return WebviewPermissionDecision.allow;
                                }
                                return WebviewPermissionDecision.deny;
                              },
                            )
                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : CameraFeedPreview(session: widget.session),
                ),
              ),
            ),
          ),
          // Screenshot Flash Overlay
          IgnorePointer(
            child: FadeTransition(
              opacity: _flashAnimation,
              child: Container(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class CameraFeedPreview extends StatelessWidget {
  final AirShiftSession session;
  const CameraFeedPreview({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final detector = session.detector;
    if (detector.cameraController == null || !detector.cameraController!.value.isInitialized) {
      return const Center(
        child: Icon(Icons.videocam_off, color: AirShiftColors.textSecondary),
      );
    }
    return CameraPreview(detector.cameraController!);
  }
}
