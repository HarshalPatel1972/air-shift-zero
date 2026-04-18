import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'checksum.dart';

class TransferManifest {
  final String token;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String checksum;

  TransferManifest({
    required this.token,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'checksum': checksum,
      };

  factory TransferManifest.fromJson(Map<String, dynamic> json) => TransferManifest(
        token: json['token'],
        fileName: json['fileName'],
        fileSize: json['fileSize'],
        mimeType: json['mimeType'],
        checksum: json['checksum'],
      );

  static Future<TransferManifest> fromFile(File file) async {
    final fileName = p.basename(file.path);
    final fileSize = await file.length();
    final checksum = await AirShiftChecksum.computeSHA256(file);
    return TransferManifest(
      token: 'grabbed-${DateTime.now().millisecondsSinceEpoch}',
      fileName: fileName,
      fileSize: fileSize,
      mimeType: 'image/png',
      checksum: checksum,
    );
  }

  String encode() => jsonEncode(toJson());
  
  static TransferManifest decode(String source) => 
      TransferManifest.fromJson(jsonDecode(source));
}
