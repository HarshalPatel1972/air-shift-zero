import 'dart:io';
import 'package:crypto/crypto.dart';

class AirShiftChecksum {
  static Future<String> computeSHA256(File file) async {
    final stream = file.openRead();
    final hash = await sha256.bind(stream).first;
    return hash.toString();
  }

  static Future<bool> verifySHA256(File file, String expected) async {
    final hex = await computeSHA256(file);
    return hex == expected;
  }
}
