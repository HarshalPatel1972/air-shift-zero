import 'dart:io';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class AirShiftScreenshotService {
  static final AirShiftScreenshotService instance = AirShiftScreenshotService._internal();
  AirShiftScreenshotService._internal();
  factory AirShiftScreenshotService() => instance;

  final ScreenshotController screenshotController = ScreenshotController();

  Future<File?> capture() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory(p.join(appDocDir.path, 'AirShift', 'Screenshots'));
      
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      String fileName = 'AirShift_Snap_${DateTime.now().millisecondsSinceEpoch}.png';
      String filePath = p.join(screenshotDir.path, fileName);

      if (Platform.isWindows) {
        debugPrint('AirShift: Initiating Fast Windows System Screenshot...');
        
        // Optimized PowerShell command: NoProfile, No execution of profile scripts, minimal assembly loading
        // We use [Drawing.Graphics]::FromImage and CopyFromScreen for instant capture
        final psCommand =  
          "Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class Dpi { [DllImport(\"user32.dll\")] public static extern bool SetProcessDPIAware(); }'; [Dpi]::SetProcessDPIAware();" +
          "[Reflection.Assembly]::LoadWithPartialName('System.Drawing');" +
          "[Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms');" +
          "\$s=[Windows.Forms.Screen]::PrimaryScreen.Bounds;" +
          "\$b=New-Object Drawing.Bitmap \$s.Width,\$s.Height;" +
          "\$g=[Drawing.Graphics]::FromImage(\$b);" +
          "\$g.CopyFromScreen(0,0,0,0,\$b.Size);" +
          "\$b.Save('${filePath.replaceAll('\\', '\\\\')}');" +
          "\$g.Dispose();\$b.Dispose();";

        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy', 'Bypass',
          '-Command', psCommand
        ]);

        if (result.exitCode != 0) {
          debugPrint('AirShift: Screenshot Failed: ${result.stderr}');
           final savedPath = await screenshotController.captureAndSave(
            screenshotDir.path,
            fileName: fileName,
          );
          return savedPath != null ? File(savedPath) : null;
        }
        
        debugPrint('AirShift: Windows System Screenshot successful: $filePath');
        return File(filePath);
      } else {
        // Fallback to widget-only capture for Android/iOS
        final savedPath = await screenshotController.captureAndSave(
          screenshotDir.path,
          fileName: fileName,
        );
        return savedPath != null ? File(savedPath) : null;
      }
    } catch (e) {
      debugPrint('Screenshot Error: $e');
      return null;
    }
  }
}
