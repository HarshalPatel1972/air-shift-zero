import 'dart:async';
import '../gesture/gesture_detector.dart';
import '../gesture/gesture_state_machine.dart';
import 'session_state.dart';
import '../discovery/mdns_service.dart';
import '../discovery/ble_proximity.dart';
import '../discovery/name_generator.dart';
import '../discovery/airshift_device.dart';

class AirShiftSession {
  SessionState _currentState = SessionState.idle;
  SessionState get currentState => _currentState;

  final detector = AirShiftGestureDetector();
  final stateMachine = GestureStateMachine();

  // Discovery Services
  final _mdns = AirShiftMdnsService();
  final _ble = AirShiftBleProximity();
  String? _currentSessionName;
  final _devicesController = StreamController<List<AirShiftDevice>>.broadcast();
  Stream<List<AirShiftDevice>> get nearbyDevices => _devicesController.stream;

  final _stateController = StreamController<SessionState>.broadcast();
  Stream<SessionState> get stateStream => _stateController.stream;

  StreamSubscription? _gestureSubscription;
  StreamSubscription? _mdnsSubscription;

  /// Starts an Air Shift session.
  void start() async {
    if (_currentState != SessionState.idle) return;
    
    _currentSessionName = AirShiftNameGenerator.generate();
    _currentState = SessionState.active;
    _stateController.add(_currentState);
    
    // Phase 2 - Start Camera and Detector
    await detector.initialize();
    _gestureSubscription = detector.gestureStream.listen((event) {
      stateMachine.onGestureEvent(event);
      onGestureEvent(event.gesture);
    });
    
    // Phase 4 - Start mDNS + BLE
    await _mdns.startAnnouncing(_currentSessionName!, 49317);
    await _mdns.startDiscovery();
    _mdnsSubscription = _mdns.devicesStream.listen((devices) {
      final proximateDevices = _ble.applyProximity(devices);
      _devicesController.add(proximateDevices);
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
    
    _currentSessionName = null;
  }

  /// State machine handler for gesture events.
  void onGestureEvent(Gesture gesture) {
    if (_currentState == SessionState.idle) return;

    // Critical Rule enforced in GestureStateMachine
    final gState = stateMachine.currentState;
    
    if (gState == GestureState.holding && _currentState != SessionState.holding) {
      _currentState = SessionState.holding;
      _stateController.add(_currentState);
      _ble.startScan(); // Start BLE scan only in HOLDING state
    } else if (gState == GestureState.cursor && _currentState != SessionState.active) {
       _currentState = SessionState.active;
       _stateController.add(_currentState);
       _ble.stopScan();
    }
  }

  void dispose() {
    end();
    _mdns.dispose();
    _stateController.close();
    _devicesController.close();
  }
}
