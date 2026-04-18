import 'dart:ui';
import 'dart:math' as math;
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
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:screenshot/screenshot.dart';
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _checkInitialPermissions();
      }
    });
  }

  Future<void> _checkInitialPermissions() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await [
      Permission.camera,
      Permission.nearbyWifiDevices,
      Permission.location,
    ].request();
    if (!(await FlutterOverlayWindow.isPermissionGranted())) {
      await FlutterOverlayWindow.requestPermission();
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
      title: 'Air Shift 0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08090A),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
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

class _FoundationScreenState extends State<FoundationScreen> with TickerProviderStateMixin {
  Offset _cursorPos = Offset.zero;
  bool _isFist = false;
  SessionState _sState = SessionState.idle;
  session_state.Gesture _currentGesture = session_state.Gesture.none;
  String _gestureName = "Engine Offline";
  
  late AnimationController _pulseController;
  late AnimationController _meshController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _meshController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

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
      if (mounted) setState(() => _sState = state);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Dynamic Mesh Background (The "Industry" Look)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _meshController,
              builder: (context, _) => CustomPaint(
                painter: MeshGradientPainter(progress: _meshController.value),
              ),
            ),
          ),
          
          // 2. Glassmorphic Surface
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          // 3. Central Neural Radar
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNeuralRadar(),
                const SizedBox(height: 60),
                _buildSystemBadge(),
              ],
            ),
          ),

          // 4. Floating Header
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AIR SHIFT', style: TextStyle(fontSize: 10, letterSpacing: 5, fontWeight: FontWeight.bold, color: Colors.white54)),
                    Text('ZERO ARCHITECTURE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
                _buildIconButton(Icons.settings_outlined, () => Navigator.pushNamed(context, '/settings')),
              ],
            ),
          ),

          // 5. Cursor & Tracking
          if (_sState != SessionState.idle) ...[
            HandCursor(isFist: _isFist, x: _cursorPos.dx, y: _cursorPos.dy),
            if (!_isFist) SelectionRing(position: _cursorPos, onComplete: () {}),
          ],

          // 6. Floating Control Center
          _buildControlCenter(),

          // 7. Mini Camera Preview (iPhone Dynamic Island Style)
          if (_sState != SessionState.idle) _buildMiniCamera(),
        ],
      ),
    );
  }

  Widget _buildNeuralRadar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) => Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.05 + 0.1 * _pulseController.value)),
          boxShadow: [
            BoxShadow(
              color: AirShiftColors.bluePrimary.withOpacity(0.05 * _pulseController.value),
              blurRadius: 100,
              spreadRadius: 20,
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Internal Rings
            ...List.generate(3, (i) => Transform.scale(
              scale: 0.3 + (i * 0.3) + (0.1 * _pulseController.value),
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05)))),
            )),
            // Core
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AirShiftColors.bluePrimary.withOpacity(0.4), Colors.transparent]),
              ),
              child: Icon(_sState == SessionState.idle ? Icons.grain : Icons.auto_awesome, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _sState == SessionState.idle ? Colors.orange : AirShiftColors.greenConfirm,
              boxShadow: [BoxShadow(color: (_sState == SessionState.idle ? Colors.orange : AirShiftColors.greenConfirm).withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _sState == SessionState.idle ? 'ENGINE READY' : 'TRACKING: ${_gestureName.toUpperCase()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenter() {
    return Positioned(
      bottom: 50,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    _sState == SessionState.idle ? 'START GESTURE ENGINE' : 'STOP ENGINE',
                    _sState == SessionState.idle ? AirShiftColors.bluePrimary : Colors.redAccent,
                    () async {
                      if (_sState == SessionState.idle) {
                        if (await Permission.camera.request().isGranted) {
                          widget.session.start();
                        }
                      } else {
                        widget.session.end();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildMiniCamera() {
    return Positioned(
      top: 130,
      right: 24,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CameraFeedPreview(session: widget.session),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final double progress;
  MeshGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Smooth animated background blobs
    void drawBlob(Offset center, double radius, Color color) {
       final gradient = RadialGradient(colors: [color.withOpacity(0.15), Colors.transparent]);
       paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
       canvas.drawCircle(center, radius, paint);
    }

    final t = progress * 2 * math.pi;
    drawBlob(Offset(size.width * 0.2 + math.sin(t) * 50, size.height * 0.3 + math.cos(t) * 50), 400, const Color(0xFF4A90E2));
    drawBlob(Offset(size.width * 0.8 + math.cos(t) * 50, size.height * 0.7 + math.sin(t) * 50), 350, const Color(0xFF9013FE));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CameraFeedPreview extends StatefulWidget {
  final AirShiftSession session;
  const CameraFeedPreview({super.key, required this.session});

  @override
  State<CameraFeedPreview> createState() => _CameraFeedPreviewState();
}

class _CameraFeedPreviewState extends State<CameraFeedPreview> {
  @override
  void initState() {
    super.initState();
    widget.session.stateStream.listen((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final detector = widget.session.detector;
    if (detector.cameraController == null || !detector.cameraController!.value.isInitialized) {
      return const Center(child: Icon(Icons.videocam_off, color: Colors.white24));
    }
    return CameraPreview(detector.cameraController!);
  }
}
