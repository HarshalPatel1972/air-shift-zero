import 'package:flutter/foundation.dart';
import 'package:shake/shake.dart';
import '../session/airshift_session.dart';
import '../session/session_state.dart';
import '../overlay/overlay_manager.dart';

class AirShiftShakeDetector {
  late ShakeDetector _detector;
  final AirShiftSession session;

  AirShiftShakeDetector({required this.session});

  void start() {
    _detector = ShakeDetector.autoStart(
      onPhoneShake: () async {
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
      },
      shakeThresholdGravity: 2.7, // Exactly 2.7G as per spec
      shakeSlopTimeMS: 500,       // 500ms debounce
      shakeCountResetTime: 3000,
    );
  }

  void stop() {
    _detector.stopListening();
  }
}
