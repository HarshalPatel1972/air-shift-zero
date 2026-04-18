import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../session/session_state.dart' as session;

class GestureEvent {
  final session.Gesture gesture;
  final double x;
  final double y;
  final String gestureName;

  GestureEvent(this.gesture, {this.x = 0, this.y = 0, this.gestureName = ""});
}

class AirShiftGestureDetector {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  
  // Desktop Bridge
  WebviewController? _desktopWebview;
  
  // Android Bridge
  WebViewController? _androidWebview;
  
  bool _isWebviewInitialized = false;
  
  final _gestureController = StreamController<GestureEvent>.broadcast();
  Stream<GestureEvent> get gestureStream => _gestureController.stream;

  CameraController? get cameraController => _cameraController;
  dynamic get webviewController => defaultTargetPlatform == TargetPlatform.windows ? _desktopWebview : _androidWebview;

  double _smoothX = 0;
  double _smoothY = 0;

  /// Initializes the camera and detector.
  Future<void> initialize() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (_isWebviewInitialized) return;
      await _initializeDesktopBridge();
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
       if (_isWebviewInitialized) return;
       await _initializeAndroidBridge();
       return;
    }
  }

  Future<void> _initializeAndroidBridge() async {
    try {
      debugPrint('Gesture Engine: Initializing Android MediaPipe Bridge...');
      
      _androidWebview = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'FlutterChannel',
          onMessageReceived: (JavaScriptMessage message) {
             _handleBridgeMessage(message.message);
          },
        );

      final String htmlContent = await rootBundle.loadString('assets/web/gesture_bridge.html');
      await _androidWebview!.loadHtmlString(htmlContent, baseUrl: 'https://appassets.androidplatform.net');
      
      _isWebviewInitialized = true;
      debugPrint('Gesture Engine: Android MediaPipe Bridge ONLINE.');
    } catch (e) {
      debugPrint('Android Bridge Init Failed: $e');
    }
  }

  void _handleBridgeMessage(String message) {
    try {
      final dynamic data = json.decode(message);
      if (data['type'] == 'landmarks') {
        final double rawX = (data['x'] as num).toDouble();
        final double rawY = (data['y'] as num).toDouble();
        final String gestureName = data['gesture'] ?? "Tracking...";
        
        session.Gesture currentGesture = session.Gesture.none;
        if (gestureName.contains('Victory')) currentGesture = session.Gesture.victory;
        else if (gestureName.contains('Open Palm')) currentGesture = session.Gesture.openPalm;
        else if (gestureName.contains('Closed Fist') || data['isFist'] == true) currentGesture = session.Gesture.fist;
        else if (gestureName.contains('Pointer')) currentGesture = session.Gesture.singleFinger;

        // Invert X for mirroring
        double targetX = (1.0 - rawX);
        double targetY = rawY;

        _smoothX = lerpDouble(_smoothX, targetX, 0.45) ?? targetX;
        _smoothY = lerpDouble(_smoothY, targetY, 0.45) ?? targetY;

        _gestureController.add(GestureEvent(
          currentGesture,
          x: _smoothX,
          y: _smoothY,
          gestureName: gestureName,
        ));
      } else if (data['type'] == 'log') {
        debugPrint('JS BRIDGE LOG: ${data['message']}');
      }
    } catch (e) {
       debugPrint('Bridge Decoding Error: $e');
    }
  }

  Future<void> _initializeDesktopBridge() async {
    try {
      _desktopWebview = WebviewController();
      await _desktopWebview!.initialize();
      await _desktopWebview!.setBackgroundColor(Color(0x00000000));
      
      _desktopWebview!.webMessage.listen((message) {
         _handleBridgeMessage(message is String ? message : json.encode(message));
      });

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/gesture_bridge.html');
      final byteData = await rootBundle.load('assets/web/gesture_bridge.html');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      await _desktopWebview!.loadUrl(tempFile.uri.toString());
      _isWebviewInitialized = true;
      debugPrint('Gesture Engine: Windows Bridge Active.');
    } catch (e) {
      debugPrint('Desktop Bridge Init Failed: $e');
    }
  }

  void startWindowEngine() {
    if (_isWebviewInitialized) {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _desktopWebview?.postWebMessage(json.encode({'command': 'START'}));
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        _androidWebview?.runJavaScript("dispatchCommand('START')");
      }
    }
  }

  void stopWindowEngine() {
    if (_isWebviewInitialized) {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        _desktopWebview?.postWebMessage(json.encode({'command': 'STOP'}));
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        _androidWebview?.runJavaScript("dispatchCommand('STOP')");
      }
    }
  }

  void updateMouseEmulator(Offset position, bool isPressed) {
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) return;
    
    _gestureController.add(GestureEvent(
      isPressed ? session.Gesture.fist : session.Gesture.singleFinger,
      x: position.dx,
      y: position.dy,
      gestureName: isPressed ? "Emulated Fist" : "Emulated Pointer",
    ));
  }

  Future<void> dispose() async {
    if (_isWebviewInitialized) {
      await _desktopWebview?.dispose();
      _isWebviewInitialized = false;
    }
    await _poseDetector?.close();
    await _gestureController.close();
  }
}
