import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class AirShiftScreenshotService {
  static final AirShiftScreenshotService instance = AirShiftScreenshotService._internal();
  AirShiftScreenshotService._internal();
  factory AirShiftScreenshotService() => instance;

  final ScreenshotController screenshotController = ScreenshotController();

  Future<File?> capture() async {
    try {
      final directory = (await getTemporaryDirectory()).path;
      String fileName = 'AirShift_Snap_${DateTime.now().millisecondsSinceEpoch}.png';

      final savedPath = await screenshotController.captureAndSave(
        directory,
        fileName: fileName,
      );
      return savedPath != null ? File(savedPath) : null;
    } catch (e) {
      debugPrint('Screenshot Error: $e');
      return null;
    }
  }
}
