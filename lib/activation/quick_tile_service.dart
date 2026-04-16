import 'package:flutter/foundation.dart';
import 'package:quick_settings/quick_settings.dart';
import '../session/airshift_session.dart';
import '../session/session_state.dart';
import '../overlay/overlay_manager.dart';

class AirShiftQuickTileService {
  static void initialize() {
    QuickSettings.setup(
      onTileClicked: onTileClicked,
      onTileAdded: onTileAdded,
      onTileRemoved: onTileRemoved,
    );
  }
}

@pragma('vm:entry-point')
void onTileClicked(Tile tile) async {
  final session = AirShiftSession.instance;
  if (session.currentState == SessionState.idle) {
    await OverlayManager.show();
    session.start();
  } else {
    session.end();
    await OverlayManager.hide();
  }
}

@pragma('vm:entry-point')
void onTileAdded(Tile tile) {
  debugPrint('Air Shift Tile Added');
}

@pragma('vm:entry-point')
void onTileRemoved(Tile tile) {
  debugPrint('Air Shift Tile Removed');
}
