import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';
import '../session/session_state.dart' as session;

class GestureEvent {
  final session.Gesture gesture;
  final double x;  // Always normalized 0..1
  final double y;  // Always normalized 0..1
  final String gestureName;
  GestureEvent(this.gesture, {this.x = 0.5, this.y = 0.5, this.gestureName = ""});
}

class AirShiftGestureDetector {
  // ── Native camera (Android) ──
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessing = false;

  // ── Desktop bridge (Windows) ──
  WebviewController? _desktopWebview;
  bool _isWebviewInitialized = false;

  final _gestureController = StreamController<GestureEvent>.broadcast();
  Stream<GestureEvent> get gestureStream => _gestureController.stream;

  CameraController? get cameraController => _cameraController;
  WebviewController? get webviewController => _desktopWebview;

  double _smoothX = 0.5;
  double _smoothY = 0.5;
  int _frameCount = 0;

  // ═══════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (_isWebviewInitialized) return;
      await _initDesktopBridge();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _initNativeCamera();
    }
  }

  void startWindowEngine() {
    if (defaultTargetPlatform == TargetPlatform.windows && _isWebviewInitialized) {
      _desktopWebview?.postWebMessage(json.encode({'command': 'START'}));
    }
    // Android: camera stream auto-starts in initialize()
  }

  void stopWindowEngine() {
    if (defaultTargetPlatform == TargetPlatform.windows && _isWebviewInitialized) {
      _desktopWebview?.postWebMessage(json.encode({'command': 'STOP'}));
    }
  }

  void updateMouseEmulator(Offset position, bool isPressed) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    _gestureController.add(GestureEvent(
      isPressed ? session.Gesture.fist : session.Gesture.singleFinger,
      x: position.dx, y: position.dy,
      gestureName: isPressed ? "Emulated Fist" : "Emulated Pointer",
    ));
  }

  Future<void> dispose() async {
    try { await _cameraController?.stopImageStream(); } catch (_) {}
    try { await _cameraController?.dispose(); } catch (_) {}
    await _desktopWebview?.dispose();
    await _poseDetector?.close();
    await _gestureController.close();
  }

  // ═══════════════════════════════════════════════════════
  //  ANDROID: Native Camera + ML Kit
  // ═══════════════════════════════════════════════════════

  Future<void> _initNativeCamera() async {
    if (!(await Permission.camera.isGranted)) {
      debugPrint('GestureEngine: Camera permission not granted');
      return;
    }

    try {
      // Clean up any old controller
      if (_cameraController != null) {
        await _cameraController?.dispose();
        _cameraController = null;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('GestureEngine: No cameras found');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(front, ResolutionPreset.low, enableAudio: false);
      
      _poseDetector = PoseDetector(options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ));

      await _cameraController!.initialize();
      debugPrint('GestureEngine: Camera initialized (${_cameraController!.value.previewSize})');

      await _cameraController!.startImageStream(_onCameraFrame);
      debugPrint('GestureEngine: Camera stream active');
    } catch (e, stack) {
      debugPrint('GestureEngine: Camera init error: $e\n$stack');
    }
  }

  void _onCameraFrame(CameraImage image) async {
    if (_isProcessing || _poseDetector == null) return;
    _isProcessing = true;
    _frameCount++;

    try {
      final inputImage = _convertImage(image);
      if (inputImage == null) { _isProcessing = false; return; }

      final poses = await _poseDetector!.processImage(inputImage);
      
      // Log every 60 frames for diagnostics
      if (_frameCount % 60 == 0) {
        debugPrint('GestureEngine: Frame #$_frameCount, poses detected: ${poses.length}');
      }

      if (poses.isNotEmpty) {
        final event = _classifyPose(poses.first, image.width.toDouble(), image.height.toDouble());
        _gestureController.add(event);
      } else {
        _gestureController.add(GestureEvent(session.Gesture.none, gestureName: 'Scanning...'));
      }
    } catch (e) {
      if (_frameCount % 120 == 0) debugPrint('GestureEngine: Process error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  GestureEvent _classifyPose(Pose pose, double imgW, double imgH) {
    final lm = pose.landmarks;
    final wrist = lm[PoseLandmarkType.rightWrist] ?? lm[PoseLandmarkType.leftWrist];
    final index = lm[PoseLandmarkType.rightIndex] ?? lm[PoseLandmarkType.leftIndex];
    final thumb = lm[PoseLandmarkType.rightThumb] ?? lm[PoseLandmarkType.leftThumb];
    final pinky = lm[PoseLandmarkType.rightPinky] ?? lm[PoseLandmarkType.leftPinky];

    // Use index finger tip as primary anchor, fall back to wrist
    final anchor = index ?? wrist;
    if (anchor == null) return GestureEvent(session.Gesture.none, gestureName: 'No hand');

    // ── NORMALIZE coordinates to 0..1 ──
    // anchor.x is in image pixel space (0..imgW), anchor.y is (0..imgH)
    double normX = anchor.x / imgW;
    double normY = anchor.y / imgH;

    // Clamp to valid range
    normX = normX.clamp(0.0, 1.0);
    normY = normY.clamp(0.0, 1.0);

    // Mirror X for front camera
    normX = 1.0 - normX;

    // Smooth
    _smoothX = lerpDouble(_smoothX, normX, 0.4) ?? normX;
    _smoothY = lerpDouble(_smoothY, normY, 0.4) ?? normY;

    // ── Gesture classification ──
    session.Gesture gesture = session.Gesture.singleFinger;
    String name = 'Pointer';

    if (wrist != null && index != null) {
      double dist(PoseLandmark a, PoseLandmark b) {
        final dx = a.x - b.x;
        final dy = a.y - b.y;
        return dx * dx + dy * dy;
      }

      final wi = dist(wrist, index);
      final wt = thumb != null ? dist(wrist, thumb) : 0.0;
      final wp = pinky != null ? dist(wrist, pinky) : 0.0;

      // Thresholds tuned for low-res mobile
      if (wi < 2000) {
        gesture = session.Gesture.fist;
        name = 'Closed Fist';
      } else if (wi > 6000 && wt > 6000) {
        gesture = session.Gesture.openPalm;
        name = 'Open Palm';
      } else if (wi > 5000 && wt < 2000 && wp < 2000) {
        gesture = session.Gesture.victory;
        name = 'Victory';
      }
    }

    if (_frameCount % 30 == 0) {
      debugPrint('GestureEngine: Tracking (${_smoothX.toStringAsFixed(2)}, ${_smoothY.toStringAsFixed(2)}) gesture=$name');
    }

    return GestureEvent(gesture, x: _smoothX, y: _smoothY, gestureName: name);
  }

  InputImage? _convertImage(CameraImage image) {
    if (_cameraController == null) return null;

    final rotation = InputImageRotation.values.firstWhere(
      (r) => r.rawValue == _cameraController!.description.sensorOrientation,
      orElse: () => InputImageRotation.rotation0deg,
    );

    // Manual YUV420 → NV21 with stride stripping
    final Uint8List bytes;
    if (image.format.group == ImageFormatGroup.yuv420) {
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      final int w = image.width;
      final int h = image.height;

      final nv21 = Uint8List(w * h + 2 * (w ~/ 2) * (h ~/ 2));

      // Y plane – strip row padding
      for (int row = 0; row < h; row++) {
        final srcOff = row * yPlane.bytesPerRow;
        nv21.setRange(row * w, (row + 1) * w,
            yPlane.bytes.buffer.asUint8List(yPlane.bytes.offsetInBytes + srcOff, w));
      }

      // Interleave V, U
      final int uvW = w ~/ 2;
      final int uvH = h ~/ 2;
      int idx = w * h;
      for (int row = 0; row < uvH; row++) {
        for (int col = 0; col < uvW; col++) {
          nv21[idx++] = vPlane.bytes[row * vPlane.bytesPerRow + col * vPlane.bytesPerPixel!];
          nv21[idx++] = uPlane.bytes[row * uPlane.bytesPerRow + col * uPlane.bytesPerPixel!];
        }
      }
      bytes = nv21;
    } else {
      final wb = WriteBuffer();
      for (final p in image.planes) wb.putUint8List(p.bytes);
      bytes = wb.done().buffer.asUint8List();
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888,
        bytesPerRow: image.width,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  WINDOWS: WebView Bridge
  // ═══════════════════════════════════════════════════════

  Future<void> _initDesktopBridge() async {
    try {
      _desktopWebview = WebviewController();
      await _desktopWebview!.initialize();
      await _desktopWebview!.setBackgroundColor(const Color(0x00000000));

      _desktopWebview!.webMessage.listen((message) {
        try {
          final data = (message is String) ? json.decode(message) : message;
          if (data['type'] == 'landmarks') {
            final rawX = (data['x'] as num).toDouble();
            final rawY = (data['y'] as num).toDouble();
            final gName = data['gesture'] ?? '';

            session.Gesture g = session.Gesture.none;
            if (gName.contains('Victory'))      g = session.Gesture.victory;
            else if (gName.contains('Open Palm'))  g = session.Gesture.openPalm;
            else if (gName.contains('Closed Fist')) g = session.Gesture.fist;
            else if (gName.contains('Pointer'))    g = session.Gesture.singleFinger;

            final tx = 1.0 - rawX;
            _smoothX = lerpDouble(_smoothX, tx, 0.45) ?? tx;
            _smoothY = lerpDouble(_smoothY, rawY, 0.45) ?? rawY;

            _gestureController.add(GestureEvent(g,
                x: _smoothX, y: _smoothY, gestureName: gName));
          } else if (data['type'] == 'log') {
            debugPrint('JS: ${data['message']}');
          }
        } catch (e) {
          debugPrint('Bridge parse: $e');
        }
      });

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/gesture_bridge.html');
      final byteData = await rootBundle.load('assets/web/gesture_bridge.html');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      await _desktopWebview!.loadUrl(tempFile.uri.toString());

      _isWebviewInitialized = true;
      debugPrint('GestureEngine: Windows bridge active');
    } catch (e) {
      debugPrint('GestureEngine: Desktop init error: $e');
    }
  }
}
