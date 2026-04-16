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
Tile? onTileClicked(Tile tile) {
  final session = AirShiftSession.instance;
  if (session.currentState == SessionState.idle) {
    OverlayManager.show();
    session.start();
    tile.tileStatus = TileStatus.active;
  } else {
    session.end();
    OverlayManager.hide();
    tile.tileStatus = TileStatus.inactive;
  }
  return tile;
}

@pragma('vm:entry-point')
Tile? onTileAdded(Tile tile) {
  debugPrint('Air Shift Tile Added');
  return tile;
}

@pragma('vm:entry-point')
void onTileRemoved() {
  debugPrint('Air Shift Tile Removed');
}
