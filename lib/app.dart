import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:webview_windows/webview_windows.dart';
import 'session/airshift_session.dart';
import 'session/session_state.dart';
import 'theme/colors.dart';
import 'gesture/hand_cursor.dart';
import 'gesture/selection_ring.dart';
import 'settings/settings_screen.dart';

// ════════════════════════════════════════════════════════════
// APP ROOT
// ════════════════════════════════════════════════════════════
class AirShiftApp extends StatelessWidget {
  const AirShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Shift Zero',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF06060A),
        fontFamily: 'Outfit',
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const FoundationScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

// ════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════
class FoundationScreen extends StatefulWidget {
  const FoundationScreen({super.key});

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen>
    with TickerProviderStateMixin {
  final _session = AirShiftSession.instance;

  late AnimationController _pulseCtrl;
  late AnimationController _meshCtrl;

  SessionState _state = SessionState.idle;
  double _rawX = 0.5;
  double _rawY = 0.5;
  bool _isFist = false;
  String _gestureName = 'Awaiting Neural Link';

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _meshCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _session.stateStream.listen((s) {
      if (mounted) setState(() => _state = s);
    });

    _session.detector.gestureStream.listen((e) {
      if (mounted) {
        setState(() {
          _rawX = e.x;
          _rawY = e.y;
          _isFist = e.gesture == Gesture.fist;
          _gestureName = e.gestureName.isNotEmpty ? e.gestureName : 'Tracking';
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _meshCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    // Convert normalized 0..1 coords to screen pixels
    final cursorX = _rawX * sz.width;
    final cursorY = _rawY * sz.height;
    final isActive = _state != SessionState.idle;

    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: Stack(
        children: [
          // ── 1. Animated mesh gradient ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _meshCtrl,
              builder: (_, __) => CustomPaint(
                painter: _MeshPainter(t: _meshCtrl.value),
              ),
            ),
          ),

          // ── 2. Frost layer ──
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: const Color(0xFF06060A).withOpacity(0.55)),
            ),
          ),

          // ── 3. Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AIR SHIFT',
                        style: TextStyle(fontSize: 9, letterSpacing: 6,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.35))),
                    const SizedBox(height: 2),
                    const Text('Zero Architecture',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                _glassCircle(Icons.tune_rounded,
                    () => Navigator.pushNamed(context, '/settings')),
              ],
            ),
          ),

          // ── 4. Central radar ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _radar(),
                const SizedBox(height: 48),
                _statusChip(),
              ],
            ),
          ),

          // ── 5. Cursor + ring ──
          if (isActive) ...[
            HandCursor(isFist: _isFist, x: cursorX, y: cursorY),
            if (!_isFist) SelectionRing(position: Offset(cursorX, cursorY), onComplete: () {}),
          ],

          // ── 6. Bottom control bar ──
          Positioned(
            bottom: 32 + MediaQuery.of(context).padding.bottom,
            left: 20, right: 20,
            child: _controlBar(isActive),
          ),

          // ── 7. Camera preview (Dynamic Island) ──
          if (isActive) _cameraIsland(),
        ],
      ),
    );
  }

  // ─── CAMERA ISLAND ─────────────────────────────────

  Widget _cameraIsland() {
    final ctrl = _session.detector.cameraController;
    final hasCamera = ctrl != null && ctrl.value.isInitialized;

    return Positioned(
      bottom: 130 + MediaQuery.of(context).padding.bottom,
      right: 20,
      child: AnimatedOpacity(
        opacity: hasCamera ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 400),
        child: Container(
          width: 110, height: 150,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: hasCamera
                ? CameraPreview(ctrl)
                : const Center(child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
          ),
        ),
      ),
    );
  }

  // ─── RADAR ─────────────────────────────────────────

  Widget _radar() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final p = _pulseCtrl.value;
        final isActive = _state != SessionState.idle;
        return Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.04 + 0.06 * p)),
            boxShadow: [
              BoxShadow(
                color: (isActive ? AirShiftColors.greenConfirm : AirShiftColors.purpleActive)
                    .withOpacity(0.06 * p),
                blurRadius: 120, spreadRadius: 30),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Transform.scale(
                  scale: 0.35 + i * 0.28 + 0.08 * p,
                  child: Container(decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.04)))),
                ),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (isActive ? AirShiftColors.greenConfirm : AirShiftColors.purpleActive).withOpacity(0.35),
                    Colors.transparent]),
                ),
                child: Icon(
                  isActive ? Icons.sensors_rounded : Icons.radio_button_unchecked,
                  color: Colors.white.withOpacity(0.9), size: 26),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── STATUS CHIP ───────────────────────────────────

  Widget _statusChip() {
    final active = _state != SessionState.idle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: active ? AirShiftColors.greenConfirm : Colors.amber,
            boxShadow: [BoxShadow(
              color: (active ? AirShiftColors.greenConfirm : Colors.amber).withOpacity(0.6),
              blurRadius: 8)])),
        const SizedBox(width: 12),
        Text(_gestureName.toUpperCase(),
          style: TextStyle(fontSize: 10, letterSpacing: 2.5,
            fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.6))),
      ]),
    );
  }

  // ─── CONTROL BAR ───────────────────────────────────

  Widget _controlBar(bool active) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(active ? 'NEURAL ENGINE ACTIVE' : 'ENGINE STANDBY',
                  style: TextStyle(fontSize: 9, letterSpacing: 2,
                    fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.35))),
                const SizedBox(height: 4),
                Text(active ? 'Precise Finger Tracking' : 'Tap to begin session',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ])),
            const SizedBox(width: 12),
            _actionBtn(
              label: active ? 'STOP' : 'START',
              color: active ? const Color(0xFFFF4757) : AirShiftColors.bluePrimary,
              onTap: () { if (active) _session.end(); else _session.start(); },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────

  Widget _actionBtn({required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 16, spreadRadius: 1)]),
        child: Text(label, style: const TextStyle(
          fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12, color: Colors.white)),
      ));
  }

  Widget _glassCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Icon(icon, color: Colors.white, size: 20)));
  }
}

// ════════════════════════════════════════════════════════════
// MESH GRADIENT PAINTER
// ════════════════════════════════════════════════════════════
class _MeshPainter extends CustomPainter {
  final double t;
  _MeshPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final p = Paint();
    void blob(Offset c, double r, Color col) {
      p.shader = RadialGradient(colors: [col.withOpacity(0.14), Colors.transparent])
          .createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, p);
    }
    blob(Offset(size.width * 0.75 + math.sin(a) * 90, size.height * 0.25 + math.cos(a) * 90), 380, const Color(0xFF7C3AED));
    blob(Offset(size.width * 0.25 + math.cos(a) * 70, size.height * 0.75 + math.sin(a) * 70), 420, const Color(0xFF06B6D4));
    blob(Offset(size.width * 0.55 + math.sin(a * 0.7) * 40, size.height * 0.5 + math.cos(a * 0.7) * 40), 300, const Color(0xFF4338CA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
