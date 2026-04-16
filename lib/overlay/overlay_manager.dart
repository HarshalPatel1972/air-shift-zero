import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:io';

class OverlayManager {
  static Future<void> show() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      if (await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.showOverlay(
          enableDrag: false,
          flag: OverlayFlag.focusPointer,
          visibility: NotificationVisibility.visibilityPublic,
          positionGravity: PositionGravity.none,
        );
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Desktop Overlay Implementation
      await Window.setEffect(effect: WindowEffect.acrylic); 
      
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setHasShadow(false);
      await windowManager.maximize();
      await windowManager.show();
    }
  }

  static Future<void> hide() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await FlutterOverlayWindow.closeOverlay();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setAsFrameless(); // Or restore original state
      await windowManager.hide();
    }
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      if (!(await FlutterOverlayWindow.isPermissionGranted())) {
        await FlutterOverlayWindow.requestPermission();
      }
    }
  }
}
