import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AirShiftHotKeyService {
  static Future<void> initialize(VoidCallback onTrigger) async {
    await hotKeyManager.unregisterAll();

    HotKey hotKey;
    if (Platform.isMacOS) {
      hotKey = HotKey(
        key: LogicalKeyboardKey.space,
        modifiers: [HotKeyModifier.meta, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
    } else {
      hotKey = HotKey(
        key: LogicalKeyboardKey.space,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );
    }

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) {
        onTrigger();
      },
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
