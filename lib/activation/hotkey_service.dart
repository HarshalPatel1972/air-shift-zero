import 'dart:io';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/material.dart';

class AirShiftHotKeyService {
  static Future<void> initialize(VoidCallback onTrigger) async {
    await hotKeyManager.unregisterAll();

    HotKey hotKey;
    if (Platform.isMacOS) {
      hotKey = HotKey(
        KeyCode.space,
        modifiers: [HotKeyModifier.command, HotKeyModifier.option],
        scope: HotKeyScope.system,
      );
    } else {
      hotKey = HotKey(
        KeyCode.space,
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
