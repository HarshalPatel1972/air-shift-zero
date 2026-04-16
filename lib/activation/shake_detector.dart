import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../session/airshift_session.dart';
import '../session/session_state.dart';
import '../overlay/overlay_manager.dart';

class AirShiftShakeDetector {
  StreamSubscription? _subscription;
  final AirShiftSession session;

  // Constants to match original shake package logic at 2.7G
  static const double shakeThresholdGravity = 2.7;
  static const int shakeSlopTimeMS = 500;
  
  DateTime? _lastShakeTime;

  AirShiftShakeDetector({required this.session});

  void start() {
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate magnitude of acceleration
      double acceleration = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z
      );
      
      // Standard gravity on Earth
      const double g = 9.80665;
      double gForce = acceleration / g;

      if (gForce > shakeThresholdGravity) {
        final now = DateTime.now();
        if (_lastShakeTime == null || 
            now.difference(_lastShakeTime!).inMilliseconds > shakeSlopTimeMS) {
          _lastShakeTime = now;
          _handleShake();
        }
      }
    });
  }

  void _handleShake() async {
    final currentState = session.currentState;
    if (currentState == SessionState.idle) {
      debugPrint('Shake detected: Starting session');
      await OverlayManager.show();
      session.start();
    } else {
      debugPrint('Shake detected: Ending session');
      session.end();
      await OverlayManager.hide();
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
