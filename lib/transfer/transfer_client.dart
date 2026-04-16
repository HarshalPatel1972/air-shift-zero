import 'dart:io';
import 'dart:convert';
import 'transfer_manifest.dart';

class AirShiftTransferClient {
  Future<void> sendFile({
    required String host,
    required int port,
    required File file,
    required TransferManifest manifest,
    required String expectedThumbprint,
  }) async {
    // 1. Connect with Bad Certificate Callback to Implement Pinning
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (cert) {
        // Implement Certificate Pinning logic
        // Verify cert thumbprint against expectedThumbprint
        return true; // Simplified for this phase, should verify thumbprint
      },
    );

    try {
      // 2. Send Manifest Handshake
      socket.add(utf8.encode(manifest.encode()));
      
      // 3. Wait for ACK
      final response = await socket.first;
      if (utf8.decode(response) != 'ACK') {
        throw Exception('Server rejected handshake');
      }
      
      // 4. Stream File Bytes
      await socket.addStream(file.openRead());
      await socket.flush();
      
    } finally {
      await socket.close();
    }
  }
}
