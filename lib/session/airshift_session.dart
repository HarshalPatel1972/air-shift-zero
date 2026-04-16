import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../gesture/gesture_detector.dart';
import '../gesture/gesture_state_machine.dart';
import 'session_state.dart';
import '../discovery/mdns_service.dart';
import '../discovery/ble_proximity.dart';
import '../discovery/name_generator.dart';
import '../discovery/airshift_device.dart';
import '../transfer/transfer_server.dart';
import '../transfer/transfer_client.dart';
import '../transfer/transfer_manifest.dart';
import '../transfer/checksum.dart';
import 'package:uuid/uuid.dart';

class AirShiftSession {
  // Singleton pattern for activation triggers
  static final AirShiftSession instance = AirShiftSession._internal();
  AirShiftSession._internal();
  factory AirShiftSession() => instance;

  SessionState _currentState = SessionState.idle;
  SessionState get currentState => _currentState;

  final detector = AirShiftGestureDetector();
  final stateMachine = GestureStateMachine();

  // Discovery Services
  final _mdns = AirShiftMdnsService();
  final _ble = AirShiftBleProximity();
  
  // Transfer Services
  final _server = AirShiftTransferServer();
  final _client = AirShiftTransferClient();
  
  final _incomingTransferController = StreamController<TransferManifest?>.broadcast();
  Stream<TransferManifest?> get incomingTransfer => _incomingTransferController.stream;

  String? _currentSessionName;
  final _devicesController = StreamController<List<AirShiftDevice>>.broadcast();
  Stream<List<AirShiftDevice>> get nearbyDevices => _devicesController.stream;

  final Set<String> _selectedFiles = {};
  Set<String> get selectedFiles => _selectedFiles;

  final _stateController = StreamController<SessionState>.broadcast();
  Stream<SessionState> get stateStream => _stateController.stream;

  StreamSubscription? _gestureSubscription;
  StreamSubscription? _mdnsSubscription;
  List<AirShiftDevice> _lastNearbyDevices = [];

  /// Starts an Air Shift session.
  void start() async {
    if (_currentState != SessionState.idle) return;
    
    _currentSessionName = AirShiftNameGenerator.generate();
    _currentState = SessionState.active;
    _stateController.add(_currentState);
    
    // Phase 5 - Start Transfer Server
    await _server.start(49317);
    
    // Phase 2 - Start Camera and Detector
    await detector.initialize();
    _gestureSubscription = detector.gestureStream.listen((event) {
      stateMachine.onGestureEvent(event);
      onGestureEvent(event.gesture);
    });
    
    // Phase 4 - Start mDNS + BLE
    await _mdns.startAnnouncing(
      _currentSessionName!, 
      49317, 
      thumbprint: _server.certThumbprint
    );
    await _mdns.startDiscovery();
    _mdnsSubscription = _mdns.devicesStream.listen((devices) {
      _lastNearbyDevices = _ble.applyProximity(devices);
      _devicesController.add(_lastNearbyDevices);
    });

    // Phase 6 - Listen to Incoming Transfers
    _server.eventStream.listen((event) {
      _incomingTransferController.add(event.manifest);
    });
  }

  /// Ends an Air Shift session.
  void end() async {
    if (_currentState == SessionState.idle) return;

    _currentState = SessionState.idle;
    _stateController.add(_currentState);

    // Phase 2 - Release Camera
    await _gestureSubscription?.cancel();
    await detector.dispose();

    // Phase 4 - Stop mDNS + BLE
    await _mdns.stopAnnouncing();
    await _mdns.stopDiscovery();
    await _mdnsSubscription?.cancel();
    _ble.stopScan();
    
    // Phase 5 - Stop Transfer Server
    await _server.stop();
    
    _currentSessionName = null;
    _lastNearbyDevices = [];
  }

  /// State machine handler for gesture events.
  void onGestureEvent(Gesture gesture) {
    if (_currentState == SessionState.idle) return;

    final prevState = _currentState;
    stateMachine.onGestureEvent(GestureEvent(gesture, x: 0, y: 0)); // Proxy to internal machine

    final gState = stateMachine.currentState;
    
    if (gState == GestureState.holding && _currentState != SessionState.holding) {
      _currentState = SessionState.holding;
      _stateController.add(_currentState);
      _ble.startScan();
    } else if (gState == GestureState.idle && _currentState != SessionState.active) {
       _currentState = SessionState.active;
       _stateController.add(_currentState);
       _ble.stopScan();
    }

    // Phase 5 - Transfer Trigger (Palm after Fist)
    if (prevState == SessionState.holding && gesture == Gesture.openPalm) {
      _initiateTransfer();
    }
  }

  void _initiateTransfer() async {
    if (_lastNearbyDevices.isEmpty) {
      debugPrint('No target devices nearby for transfer');
      return;
    }

    _currentState = SessionState.transferring;
    _stateController.add(_currentState);

    final target = _lastNearbyDevices.first;
    debugPrint('Initiating transfer to: ${target.sessionName} @ ${target.ipAddress}');

    // File size based timeout logic
    // Duration timeout = _getTransferTimeout(fileSize);
    
    // Implementation of actual file client call would go here in E2E setup
  }

  Duration _getTransferTimeout(int fileSizeBytes) {
    if (fileSizeBytes < 10 * 1024 * 1024) return const Duration(seconds: 10);
    if (fileSizeBytes < 1024 * 1024 * 1024) return const Duration(seconds: 30);
    return const Duration(seconds: 60);
  }

  void dispose() {
    end();
    _mdns.dispose();
    _stateController.close();
    _devicesController.close();
  }
}
