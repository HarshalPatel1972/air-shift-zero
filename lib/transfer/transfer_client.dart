import 'package:basic_utils/basic_utils.dart';
import 'transfer_manifest.dart';

class AirShiftTransferClient {
  Future<void> sendFile({
    required String host,
    required int port,
    required File file,
    required TransferManifest manifest,
    required String expectedThumbprint,
  }) async {
    // 1. Connect with Certificate Pinning Enforcement
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (X509Certificate cert) {
        // Standard Pinning: SHA-256 of the DER (binary) certificate
        final actualThumbprint = CryptoUtils.getHash(cert.der, algorithm: 'SHA-256');
        
        final isPinned = actualThumbprint == expectedThumbprint;
        if (!isPinned) {
          debugPrint('SECURITY ALERT: Identity Pinning failed! Expected: $expectedThumbprint, Actual: $actualThumbprint');
        }
        return isPinned;
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
