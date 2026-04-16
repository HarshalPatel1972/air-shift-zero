import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
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

  /// Initializes the camera and detector.
  Future<void> initialize() async {
    if (kIsWeb || ! (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      // Desktop skip gesture engine entirely as per Phase 9 spec
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use front camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    _poseDetector = PoseDetector(options: PoseDetectorOptions());

    await _cameraController?.initialize();
    _cameraController?.startImageStream(_processCameraImage);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _poseDetector == null) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

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

  GestureEvent _classifyGesture(Pose pose, double width, double height) {
    final landmarks = pose.landmarks;
    
    final wrist = landmarks[PoseLandmarkType.rightWrist] ?? landmarks[PoseLandmarkType.leftWrist];
    final index = landmarks[PoseLandmarkType.rightIndex] ?? landmarks[PoseLandmarkType.leftIndex];
    final thumb = landmarks[PoseLandmarkType.rightThumb] ?? landmarks[PoseLandmarkType.leftThumb];
    final pinky = landmarks[PoseLandmarkType.rightPinky] ?? landmarks[PoseLandmarkType.leftPinky];

    if (wrist == null || index == null || thumb == null || pinky == null) {
      return GestureEvent(session.Gesture.none);
    }

    // Normalized distances relative to a "hand size" estimation (wrist to index distance if hand was open)
    // But since we don't know if it's open, we'll use raw pixel distance thresholds for now, 
    // or better, use the ratio between wrist-index and wrist-pinky distances.
    
    double dist(PoseLandmark a, PoseLandmark b) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      return (dx * dx + dy * dy); // squared distance for performance
    }

    final wristToIndex = dist(wrist, index);
    final wristToThumb = dist(wrist, thumb);
    final wristToPinky = dist(wrist, pinky);

    // Heuristics for classification (will need fine-tuning with real data)
    const thresholdFist = 2500.0; // Small distance
    const thresholdOpen = 8000.0; // Large distance

    bool indexExtended = wristToIndex > thresholdOpen;
    bool thumbExtended = wristToThumb > thresholdOpen;
    bool pinkyExtended = wristToPinky > thresholdOpen;

    session.Gesture gesture;
    if (indexExtended && thumbExtended && pinkyExtended) {
      gesture = session.Gesture.openPalm;
    } else if (indexExtended && !thumbExtended && !pinkyExtended) {
      gesture = session.Gesture.singleFinger;
    } else if (!indexExtended && !thumbExtended && !pinkyExtended) {
      gesture = session.Gesture.fist;
    } else {
      gesture = session.Gesture.none;
    }

    // Flip X for selfie view
    return GestureEvent(gesture, x: width - index.x, y: index.y);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation = _cameraController!.description.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (defaultTargetPlatform == TargetPlatform.android &&
            format != InputImageFormat.nv21) ||
        (defaultTargetPlatform == TargetPlatform.iOS &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    await _poseDetector?.close();
    await _gestureController.close();
  }
}
