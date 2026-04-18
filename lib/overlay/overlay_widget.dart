import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:screenshot/screenshot.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../gesture/hand_cursor.dart';
import '../gesture/selection_ring.dart';
import '../session/airshift_session.dart';
import '../session/session_state.dart' as session_state;
import '../transfer/screenshot_service.dart';
import 'file_grid.dart';
import 'device_radar.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _appearController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  final _session = AirShiftSession();
  Offset _cursorPos = Offset.zero;
  bool _isFist = false;
  String _gestureName = "Tracking...";

  @override
  void initState() {
    super.initState();
    _appearController = AnimationController(
      vsync: this,
      duration: AirShiftMotion.overlayAppear,
    );
    _opacityAnimation = CurvedAnimation(parent: _appearController, curve: Curves.easeInOut);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _appearController, curve: Curves.easeInOut),
    );

    _session.start();
    _session.detector.gestureStream.listen((event) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _cursorPos = Offset(event.x * size.width, event.y * size.height);
          _isFist = (event.gesture == session_state.Gesture.fist);
          _gestureName = event.gestureName;
        });
      }
    });

    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: AirShiftScreenshotService.instance.screenshotController,
      child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
          child: Listener(
            onPointerMove: (event) {
              if (defaultTargetPlatform != TargetPlatform.android) {
                _session.detector.updateMouseEmulator(event.localPosition, event.buttons != 0);
              }
            },
            onPointerDown: (event) {
              if (defaultTargetPlatform != TargetPlatform.android) {
                _session.detector.updateMouseEmulator(event.localPosition, true);
              }
            },
            onPointerUp: (event) {
              if (defaultTargetPlatform != TargetPlatform.android) {
                _session.detector.updateMouseEmulator(event.localPosition, false);
              }
            },
            child: Stack(
              children: [
                // Frosted Glass Layer
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AirShiftColors.glassSurface,
                          border: Border.all(
                            color: AirShiftColors.glassBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AirShiftColors.bluePrimary.withOpacity(0.05),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Camera Feedback / Hologram Preview
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    width: 160,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AirShiftColors.bluePrimary.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: defaultTargetPlatform == TargetPlatform.windows
                          ? (_session.detector.webviewController != null
                              ? Webview(
                                  _session.detector.webviewController!,
                                  permissionRequested: (url, kind, isUserInitiated) async {
                                    if (kind == WebviewPermissionKind.camera) {
                                      return WebviewPermissionDecision.allow;
                                    }
                                    return WebviewPermissionDecision.deny;
                                  },
                                )
                              : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
                          : const CameraPreviewWidget(),
                    ),
                  ),
                ),

                // Device Radar Background
                const Center(
                  child: SizedBox(
                    width: 400,
                    height: 400,
                    child: DeviceRadar(),
                  ),
                ),

                // File Grid
                const FileGrid(),

                // Gesture Feedback (Always on Top)
                HandCursor(
                  isFist: _isFist,
                  x: _cursorPos.dx,
                  y: _cursorPos.dy,
                ),
                
                if (!_isFist)
                  SelectionRing(
                    position: _cursorPos,
                    onComplete: () {
                      // Trigger logic
                    },
                  ),

                // Blue border glow
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AirShiftColors.bluePrimary.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // Debug STATUS HUD
                Positioned(
                  bottom: 15,
                  left: 15,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TRACKING: $_gestureName\nPOS: (${_cursorPos.dx.toStringAsFixed(0)}, ${_cursorPos.dy.toStringAsFixed(0)})',
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    ),
    );
  }
}

class CameraPreviewWidget extends StatelessWidget {
  const CameraPreviewWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final detector = AirShiftSession.instance.detector;
    if (detector.cameraController == null || !detector.cameraController!.value.isInitialized) {
      return const Center(child: Icon(Icons.videocam_off, color: AirShiftColors.textSecondary));
    }
    return CameraPreview(detector.cameraController!);
  }
}
