import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
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
  String? Function()? onGetGrabbedFile;

  final _eventController = StreamController<IncomingTransferEvent>.broadcast();
  Stream<IncomingTransferEvent> get eventStream => _eventController.stream;
  
  String? get certThumbprint {
    if (_certPem == null) return null;
    final base64Content = _certPem!.split('\n')
        .where((line) => !line.startsWith('-----'))
        .join('').replaceAll('\r', '').replaceAll('\n', '').trim();
    final derBytes = base64.decode(base64Content);
    return sha256.convert(derBytes).toString();
  }

  Future<void> start(int port) async {
    final keyPair = CryptoUtils.generateRSAKeyPair();
    final privKey = keyPair.privateKey as pc.RSAPrivateKey;
    final pubKey = keyPair.publicKey as pc.RSAPublicKey;
    
    final dn = {'CN': 'AirShift-${DateTime.now().millisecondsSinceEpoch}'};
    final csrPem = X509Utils.generateRsaCsrPem(dn, privKey, pubKey);
    _certPem = X509Utils.generateSelfSignedCertificate(privKey, csrPem, 1);
    final privKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);

    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(_certPem!))
      ..usePrivateKeyBytes(utf8.encode(privKeyPem));

    _server = await SecureServerSocket.bind(InternetAddress.anyIPv4, port, context);
    _server?.listen(_handleConnection);
  }

  void _handleConnection(SecureSocket socket) {
    bool handshakeDone = false;
    TransferManifest? pushManifest;
    IOSink? fileSink;

    socket.listen((data) async {
      try {
        if (!handshakeDone) {
          handshakeDone = true;
          final raw = utf8.decode(data);
          
          if (raw == 'PULL') {
            final path = onGetGrabbedFile?.call();
            if (path == null) {
              socket.add(utf8.encode('ERROR:EMPTY'));
              socket.destroy();
              return;
            }
            final file = File(path);
            final manifest = await TransferManifest.fromFile(file);
            socket.add(utf8.encode(manifest.encode()));
            // Wait for ACK on next data chunk or just stream? 
            // We'll just stream for now.
            await socket.addStream(file.openRead());
            socket.destroy();
          } else {
            pushManifest = TransferManifest.decode(raw);
            _eventController.add(IncomingTransferEvent(pushManifest!));
            socket.add(utf8.encode('ACK'));
            
            final savePath = await AirShiftSaveLocation.resolvePath(pushManifest!.fileName, pushManifest!.mimeType);
            final file = File(savePath);
            fileSink = file.openWrite();
            // Data after the manifest in the same packet? Handled by subsequent logic
          }
        } else if (fileSink != null) {
          fileSink!.add(data);
        }
      } catch (e) {
        debugPrint('Server Connection Error: $e');
        socket.destroy();
      }
    }, onDone: () async {
      if (fileSink != null) {
        await fileSink!.close();
        // Validation logic can go here
      }
    });
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
