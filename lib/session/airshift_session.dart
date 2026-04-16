import 'dart:async';
import 'session_state.dart';

class AirShiftSession {
  SessionState _currentState = SessionState.idle;
  SessionState get currentState => _currentState;

  final _stateController = StreamController<SessionState>.broadcast();
  Stream<SessionState> get stateStream => _stateController.stream;

  /// Starts an Air Shift session.
  /// Sets state to active, and would start camera, BLE, and mDNS in later phases.
  void start() {
    if (_currentState != SessionState.idle) return;
    
    _currentState = SessionState.active;
    _stateController.add(_currentState);
    
    // TODO: Phase 2 - Start Camera
    // TODO: Phase 4 - Start mDNS + BLE
  }

  /// Ends an Air Shift session.
  /// Sets state to idle, and would EXPLICITLY stop camera, BLE, and mDNS in later phases.
  void end() {
    if (_currentState == SessionState.idle) return;

    _currentState = SessionState.idle;
    _stateController.add(_currentState);

    // TODO: Phase 2 - Release Camera
    // TODO: Phase 4 - Stop mDNS + BLE
  }

  /// State machine handler for gesture events.
  void onGestureEvent(Gesture gesture) {
    if (_currentState == SessionState.idle) return;

    // This logic will be fleshed out in Phase 2
    switch (gesture) {
      case Gesture.singleFinger:
        // Handle cursor move/select
        break;
      case Gesture.fist:
        if (_currentState == SessionState.active) {
          _currentState = SessionState.holding;
          _stateController.add(_currentState);
        }
        break;
      case Gesture.openPalm:
        if (_currentState == SessionState.holding) {
          _currentState = SessionState.transferring;
          _stateController.add(_currentState);
          // Trigger transfer logic
        }
        break;
      case Gesture.none:
        break;
    }
  }

  void dispose() {
    _stateController.close();
  }
}
