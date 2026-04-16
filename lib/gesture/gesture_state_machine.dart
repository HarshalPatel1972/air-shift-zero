import 'dart:async';
import 'package:flutter/material.dart';
import '../session/session_state.dart' as session;
import 'gesture_detector.dart';

class GestureStateMachine {
  session.GestureState _currentState = session.GestureState.idle;
  session.GestureState get currentState => _currentState;

  final _stateController = StreamController<session.GestureState>.broadcast();
  Stream<session.GestureState> get stateStream => _stateController.stream;

  final _transferTriggerController = StreamController<void>.broadcast();
  Stream<void> get transferTriggerStream => _transferTriggerController.stream;

  final _selectionController = StreamController<Offset>.broadcast();
  Stream<Offset> get selectionStream => _selectionController.stream;

  Timer? _holdingTimeout;

  void onGestureEvent(GestureEvent event) {
    switch (_currentState) {
      case session.GestureState.idle:
        if (event.gesture == session.Gesture.singleFinger) {
          _updateState(session.GestureState.cursor);
        }
        break;

      case session.GestureState.cursor:
        if (event.gesture == session.Gesture.fist) {
          _updateState(session.GestureState.holding);
          _startHoldingTimeout();
        } else if (event.gesture == session.Gesture.singleFinger) {
          _selectionController.add(Offset(event.x, event.y));
        } else if (event.gesture == session.Gesture.none) {
          _updateState(session.GestureState.idle);
        }
        // Critical Rule: openPalm is ignored in CURSOR state
        break;

      case session.GestureState.holding:
        if (event.gesture == session.Gesture.openPalm) {
          // THE ONLY VALID TRANSFER TRIGGER
          _transferTriggerController.add(null);
          _cancelHoldingTimeout();
          _updateState(session.GestureState.idle);
        } else if (event.gesture == session.Gesture.none) {
          // User moved away
        }
        break;
    }
  }

  void _updateState(session.GestureState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    _stateController.add(_currentState);
  }

  void _startHoldingTimeout() {
    _holdingTimeout?.cancel();
    _holdingTimeout = Timer(const Duration(seconds: 10), () {
      if (_currentState == session.GestureState.holding) {
        _updateState(session.GestureState.idle);
      }
    });
  }

  void _cancelHoldingTimeout() {
    _holdingTimeout?.cancel();
  }

  void dispose() {
    _stateController.close();
    _transferTriggerController.close();
    _selectionController.close();
    _holdingTimeout?.cancel();
  }
}
