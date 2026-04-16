import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart' as pc;
import 'transfer_manifest.dart';
import 'checksum.dart';
import 'save_location.dart';

class IncomingTransferEvent {
  final TransferManifest manifest;
  final String? filePath; // Null if not finished
  final bool isFailed;

  IncomingTransferEvent(this.manifest, {this.filePath, this.isFailed = false});
}

class AirShiftTransferServer {
  SecureServerSocket? _server;
  String? _certPem;

  final _eventController = StreamController<IncomingTransferEvent>.broadcast();
  Stream<IncomingTransferEvent> get eventStream => _eventController.stream;
  String? get certThumbprint {
    if (_certPem == null) return null;
    return CryptoUtils.getHash(Uint8List.fromList(utf8.encode(_certPem!)));
  }

  Future<void> start(int port) async {
    // 1. Generate RSA KeyPair
    final keyPair = CryptoUtils.generateRSAKeyPair();
    final privKey = keyPair.privateKey as pc.RSAPrivateKey;
    final pubKey = keyPair.publicKey as pc.RSAPublicKey;
    
    // 2. Generate Self-Signed Cert
    final dn = {'CN': 'AirShift-${DateTime.now().millisecondsSinceEpoch}'};
    final csrPem = X509Utils.generateRsaCsrPem(dn, privKey, pubKey);
    _certPem = X509Utils.generateSelfSignedCertificate(privKey, csrPem, 1); // 1 day validity
    
    final privKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);

    // 3. Setup SecurityContext
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(_certPem!))
      ..usePrivateKeyBytes(utf8.encode(privKeyPem));

    // 4. Start Server
    _server = await SecureServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
      context,
    );

    _server?.listen(_handleConnection);
  }

  void _handleConnection(SecureSocket socket) async {
    TransferManifest? manifest;
    try {
      // 1. Read Manifest Handshake
      final data = await socket.first;
      manifest = TransferManifest.decode(utf8.decode(data));
      
      // Emit Start Event
      _eventController.add(IncomingTransferEvent(manifest));

      // 2. ACK
      socket.add(utf8.encode('ACK'));
      
      // 3. Receive File Stream
      final savePath = await AirShiftSaveLocation.resolvePath(manifest.fileName, manifest.mimeType);
      final file = File(savePath);
      final sink = file.openWrite();
      
      await sink.addStream(socket);
      await sink.close();
      
      // 4. Verify Checksum
      final isValid = await AirShiftChecksum.verifySHA256(file, manifest.checksum);
      if (!isValid) {
        await file.delete();
        throw Exception('Checksum mismatch - deleted corrupted file');
      }
      
      // Emit Success Event
      _eventController.add(IncomingTransferEvent(manifest, filePath: savePath));
    } catch (e) {
      if (manifest != null) {
        _eventController.add(IncomingTransferEvent(manifest, isFailed: true));
      }
      print('Transfer Conflict: $e');
    } finally {
      socket.destroy();
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  void dispose() {
    stop();
    _eventController.close();
  }
}
