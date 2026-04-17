import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../session/session_state.dart' as session;

class GestureEvent {
  final session.Gesture gesture;
  final double x;
  final double y;

  GestureEvent(this.gesture, {this.x = 0, this.y = 0});
}

class AirShiftGestureDetector {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isProcessing = false;
  
  final _gestureController = StreamController<GestureEvent>.broadcast();
  Stream<GestureEvent> get gestureStream => _gestureController.stream;

  CameraController? get cameraController => _cameraController;

  double _smoothX = 0;
  double _smoothY = 0;

  /// Initializes the camera and detector.
  Future<void> initialize() async {
    // 1. Handle Permissions (Mobile)
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        await Permission.camera.request();
      }
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('Gesture Engine: No cameras found. Falling back to Mouse mode.');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      // Only Initialize ML Kit on Mobile
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        _poseDetector = PoseDetector(options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ));
      }

      await _cameraController?.initialize();
      
      // ONLY start image stream on Mobile (Unsupported on Windows/Desktop)
      if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
        _cameraController?.startImageStream(_processCameraImage);
      }
      
      debugPrint('Gesture Engine: Camera active on ${defaultTargetPlatform.name}');
    } catch (e) {
      debugPrint('Gesture Engine Initialization Error: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    // Skip ML processing on Windows/Desktop (Native plugin limitation)
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
       return; 
    }

    if (_isProcessing || _poseDetector == null) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isNotEmpty) {
        final gestureEvent = _classifyGesture(poses.first, image.width.toDouble(), image.height.toDouble());
        _gestureController.add(gestureEvent);
      } else {
        _gestureController.add(GestureEvent(session.Gesture.none));
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Exposed for Windows/Desktop testing to emulate hand movement
  void updateMouseEmulator(Offset position, bool isPressed) {
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) return;
    
    _gestureController.add(GestureEvent(
      isPressed ? session.Gesture.fist : session.Gesture.singleFinger,
      x: position.dx,
      y: position.dy,
    ));
  }

  GestureEvent _classifyGesture(Pose pose, double width, double height) {
    final landmarks = pose.landmarks;
    
    final wrist = landmarks[PoseLandmarkType.rightWrist] ?? landmarks[PoseLandmarkType.leftWrist];
    final index = landmarks[PoseLandmarkType.rightIndex] ?? landmarks[PoseLandmarkType.leftIndex];
    final thumb = landmarks[PoseLandmarkType.rightThumb] ?? landmarks[PoseLandmarkType.leftThumb];
    final pinky = landmarks[PoseLandmarkType.rightPinky] ?? landmarks[PoseLandmarkType.leftPinky];

    if (wrist == null || index == null) {
      return GestureEvent(session.Gesture.none);
    }

    double dist(PoseLandmark a, PoseLandmark b) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      return (dx * dx + dy * dy);
    }

    final wristToIndex = dist(wrist, index);
    final wristToThumb = thumb != null ? dist(wrist, thumb) : 0.0;
    final wristToPinky = pinky != null ? dist(wrist, pinky) : 0.0;

    const thresholdOpen = 12000.0;
    const thresholdFist = 4000.0;
    const thresholdVictory = 9000.0;

    session.Gesture gesture;
    
    if (wristToIndex > thresholdVictory && wristToThumb < thresholdFist && wristToPinky < thresholdFist) {
       gesture = session.Gesture.victory;
    } else if (wristToIndex > thresholdOpen && wristToThumb > thresholdOpen) {
      gesture = session.Gesture.openPalm;
    } else if (wristToIndex < thresholdFist) {
      gesture = session.Gesture.fist;
    } else if (wristToIndex > thresholdOpen) {
      gesture = session.Gesture.singleFinger;
    } else {
      gesture = session.Gesture.none;
    }

    double targetX = width - index.x;
    double targetY = index.y;
    _smoothX = lerpDouble(_smoothX, targetX, 0.45) ?? targetX;
    _smoothY = lerpDouble(_smoothY, targetY, 0.45) ?? targetY;

    return GestureEvent(gesture, x: _smoothX, y: _smoothY);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // YUV Concat Fix for Android - Ensuring 100% data pass
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    await _poseDetector?.close();
    await _gestureController.close();
  }
}
