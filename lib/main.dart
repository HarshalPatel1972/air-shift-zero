import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'dart:io';

import 'app.dart';
import 'overlay/overlay_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!Platform.isAndroid && !Platform.isIOS) {
    await windowManager.ensureInitialized();
    await acrylic.Window.initialize();
  }

  runApp(const AirShiftApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayWidget());
}
