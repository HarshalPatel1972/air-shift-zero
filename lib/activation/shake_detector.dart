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
        if (session.currentState == SessionState.idle) {
          await OverlayManager.show();
          session.start();
        } else {
          session.end();
          await OverlayManager.hide();
        }
      },
      shakeThresholdGravity: 2.7, // Approx 26 m/s^2, can be tuned
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
    );
  }

  void stop() {
    _detector.stopListening();
  }
}
