import 'dart:async';
import '../gesture/gesture_detector.dart';
import '../gesture/gesture_state_machine.dart';
import 'session_state.dart';

class AirShiftSession {
  SessionState _currentState = SessionState.idle;
  SessionState get currentState => _currentState;

  final detector = AirShiftGestureDetector();
  final stateMachine = GestureStateMachine();

  final _stateController = StreamController<SessionState>.broadcast();
  Stream<SessionState> get stateStream => _stateController.stream;

  StreamSubscription? _gestureSubscription;

  /// Starts an Air Shift session.
  void start() async {
    if (_currentState != SessionState.idle) return;
    
    _currentState = SessionState.active;
    _stateController.add(_currentState);
    
    // Phase 2 - Start Camera and Detector
    await detector.initialize();
    _gestureSubscription = detector.gestureStream.listen((event) {
      stateMachine.onGestureEvent(event);
      onGestureEvent(event.gesture);
    });
    
    // TODO: Phase 4 - Start mDNS + BLE
  }

  /// Ends an Air Shift session.
  void end() async {
    if (_currentState == SessionState.idle) return;

    _currentState = SessionState.idle;
    _stateController.add(_currentState);

    // Phase 2 - Release Camera
    await _gestureSubscription?.cancel();
    await detector.dispose();

    // TODO: Phase 4 - Stop mDNS + BLE
  }

  /// State machine handler for gesture events.
  void onGestureEvent(Gesture gesture) {
    if (_currentState == SessionState.idle) return;

    // Critical Rule enforced in GestureStateMachine
    final gState = stateMachine.currentState;
    
    if (gState == GestureState.holding && _currentState != SessionState.holding) {
      _currentState = SessionState.holding;
      _stateController.add(_currentState);
    } else if (gState == GestureState.idle && _currentState != SessionState.active) {
       _currentState = SessionState.active;
       _stateController.add(_currentState);
    }
  }

  void dispose() {
    _gestureSubscription?.cancel();
    detector.dispose();
    stateMachine.dispose();
    _stateController.close();
  }
}
