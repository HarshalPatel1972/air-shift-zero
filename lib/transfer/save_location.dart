import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AirShiftSaveLocation {
  static Future<String> resolvePath(String fileName, String mimeType) async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      if (mimeType.startsWith('image/')) {
        baseDir = Directory('/storage/emulated/0/Pictures/AirShift');
      } else if (mimeType.startsWith('video/')) {
        baseDir = Directory('/storage/emulated/0/Movies/AirShift');
      } else if (mimeType == 'application/pdf') {
        baseDir = Directory('/storage/emulated/0/Documents/AirShift');
      }
    }

    baseDir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return p.join(baseDir.path, fileName);
  }
}
