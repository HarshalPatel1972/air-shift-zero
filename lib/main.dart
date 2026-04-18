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

import 'settings/settings_model.dart';

// Global session for activation triggers
final globalSession = AirShiftSession.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Phase 8 - Load Settings
    await AirShiftSettings.instance.load();
  } catch (e) {
    debugPrint('Settings error: $e');
  }
  
  // Phase 3 - Desktop window setup
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();
      await acrylic.Window.initialize();
    } catch (e) {
      debugPrint('Desktop Window Error: $e');
    }

    try {
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
    } catch (e) {
      debugPrint('HotKey Service Error: $e');
    }
  }

  // Phase 7 - Android Activation Setup
  if (Platform.isAndroid) {
    try {
      AirShiftQuickTileService.initialize();
    } catch (e) {
      debugPrint('QuickTile Error: $e');
    }
  }

  runApp(const AirShiftApp());

  // Phase 9 - Pre-warm Gesture Engine for instant activation
  if (Platform.isWindows) {
    globalSession.detector.initialize();
  }
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayWidget());
}
