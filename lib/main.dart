import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'dart:io';

import 'app.dart';
import 'overlay/overlay_widget.dart';
import 'activation/quick_tile_service.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'activation/hotkey_service.dart';
import 'session/airshift_session.dart';
import 'session/session_state.dart';
import 'overlay/overlay_manager.dart';

// Global session for activation triggers
final globalSession = AirShiftSession.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Phase 3 - Desktop window setup
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await acrylic.Window.initialize();
  }

  // Phase 7 - Activation Setup
  AirShiftQuickTileService.initialize();
  await hotKeyManager.ensureInitialized();
  
  await AirShiftHotKeyService.initialize(() async {
    final session = AirShiftSession.instance;
    if (session.currentState == SessionState.idle) {
      await OverlayManager.show();
      session.start();
    } else {
      session.end();
      await OverlayManager.hide();
    }
  });

  runApp(const AirShiftApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayWidget());
}
