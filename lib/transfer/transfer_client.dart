import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'transfer_manifest.dart';
import '../discovery/airshift_device.dart';
import 'save_location.dart';
import 'checksum.dart';

class AirShiftTransferClient {
  Future<File?> requestTransfer(AirShiftDevice device) async {
    final socket = await SecureSocket.connect(
      device.ipAddress,
      device.port,
      onBadCertificate: (X509Certificate cert) {
        if (device.thumbprint == null) return true;
        final actualThumbprint = sha256.convert(cert.der).toString();
        return actualThumbprint == device.thumbprint;
      },
      timeout: const Duration(seconds: 5),
    );

    try {
      // 1. Send Pull Request
      socket.add(utf8.encode('PULL'));
      
      // 2. Receive Manifest
      final Completer<TransferManifest> manifestCompleter = Completer();
      final List<int> buf = [];
      
      final subscription = socket.listen((data) {
        if (!manifestCompleter.isCompleted) {
           buf.addAll(data);
           try {
             final str = utf8.decode(buf);
             if (str.contains('}')) {
               manifestCompleter.complete(TransferManifest.decode(str));
             }
           } catch (_) {}
        }
      });

      final manifest = await manifestCompleter.future.timeout(const Duration(seconds: 5));
      subscription.pause();

      // 3. Send ACK
      socket.add(utf8.encode('ACK'));
      
      // 4. Receive File
      final savePath = await AirShiftSaveLocation.resolvePath(manifest.fileName, manifest.mimeType);
      final file = File(savePath);
      final sink = file.openWrite();
      
      subscription.resume();
      await sink.addStream(socket);
      await sink.close();

      // 5. Verify Checksum
      final isValid = await AirShiftChecksum.verifySHA256(file, manifest.checksum);
      if (!isValid) {
        await file.delete();
        return null;
      }
      return file;
    } catch (e) {
      debugPrint('Pull Transfer Error: $e');
      return null;
    } finally {
      await socket.close();
    }
  }

  Future<void> sendFile({
    required String host,
    required int port,
    required File file,
    required TransferManifest manifest,
    required String expectedThumbprint,
  }) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (X509Certificate cert) {
        final actualThumbprint = sha256.convert(cert.der).toString();
        return actualThumbprint == expectedThumbprint;
      },
    );

    try {
      socket.add(utf8.encode(manifest.encode()));
      final response = await socket.first;
      if (utf8.decode(response) != 'ACK') {
        throw Exception('Server rejected handshake');
      }
      await socket.addStream(file.openRead());
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}
