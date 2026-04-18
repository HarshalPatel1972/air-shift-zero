import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';

// --- Win32 FFI Definitions ---
typedef GetDC_C = Pointer<Void> Function(Pointer<Void> hWnd);
typedef GetDC_Dart = Pointer<Void> Function(Pointer<Void> hWnd);

typedef CreateCompatibleDC_C = Pointer<Void> Function(Pointer<Void> hDC);
typedef CreateCompatibleDC_Dart = Pointer<Void> Function(Pointer<Void> hDC);

typedef CreateCompatibleBitmap_C = Pointer<Void> Function(Pointer<Void> hDC, Int32 width, Int32 height);
typedef CreateCompatibleBitmap_Dart = Pointer<Void> Function(Pointer<Void> hDC, int width, int height);

typedef SelectObject_C = Pointer<Void> Function(Pointer<Void> hDC, Pointer<Void> hGDIObj);
typedef SelectObject_Dart = Pointer<Void> Function(Pointer<Void> hDC, Pointer<Void> hGDIObj);

typedef BitBlt_C = Int32 Function(Pointer<Void> hdcDest, Int32 xDest, Int32 yDest, Int32 width, Int32 height, Pointer<Void> hdcSrc, Int32 xSrc, Int32 ySrc, Uint32 rop);
typedef BitBlt_Dart = int Function(Pointer<Void> hdcDest, int xDest, int yDest, int width, int height, Pointer<Void> hdcSrc, int xSrc, int ySrc, int rop);

typedef DeleteObject_C = Int32 Function(Pointer<Void> hGDIObj);
typedef DeleteObject_Dart = int Function(Pointer<Void> hGDIObj);

typedef ReleaseDC_C = Int32 Function(Pointer<Void> hWnd, Pointer<Void> hDC);
typedef ReleaseDC_Dart = int Function(Pointer<Void> hWnd, Pointer<Void> hDC);

typedef GetDIBits_C = Int32 Function(Pointer<Void> hdc, Pointer<Void> hbm, Uint32 start, Uint32 lines, Pointer<Void> lpvBits, Pointer<Void> lpbmi, Uint32 usage);
typedef GetDIBits_Dart = int Function(Pointer<Void> hdc, Pointer<Void> hbm, int start, int lines, Pointer<Void> lpvBits, Pointer<Void> lpbmi, int usage);

class AirShiftScreenshotService {
  static final AirShiftScreenshotService instance = AirShiftScreenshotService._internal();
  AirShiftScreenshotService._internal() {
    if (Platform.isWindows) {
      _initWin32();
    }
  }
  factory AirShiftScreenshotService() => instance;

  final ScreenshotController screenshotController = ScreenshotController();

  // Win32 dynamic libraries
  late DynamicLibrary _user32;
  late DynamicLibrary _gdi32;

  // Function pointers
  late GetDC_Dart _getDC;
  late CreateCompatibleDC_Dart _createCompatibleDC;
  late CreateCompatibleBitmap_Dart _createCompatibleBitmap;
  late SelectObject_Dart _selectObject;
  late BitBlt_Dart _bitBlt;
  late DeleteObject_Dart _deleteObject;
  late ReleaseDC_Dart _releaseDC;
  late GetDIBits_Dart _getDIBits;

  void _initWin32() {
    _user32 = DynamicLibrary.open('user32.dll');
    _gdi32 = DynamicLibrary.open('gdi32.dll');

    _getDC = _user32.lookupFunction<GetDC_C, GetDC_Dart>('GetDC');
    _releaseDC = _user32.lookupFunction<ReleaseDC_C, ReleaseDC_Dart>('ReleaseDC');
    
    _createCompatibleDC = _gdi32.lookupFunction<CreateCompatibleDC_C, CreateCompatibleDC_Dart>('CreateCompatibleDC');
    _createCompatibleBitmap = _gdi32.lookupFunction<CreateCompatibleBitmap_C, CreateCompatibleBitmap_Dart>('CreateCompatibleBitmap');
    _selectObject = _gdi32.lookupFunction<SelectObject_C, SelectObject_Dart>('SelectObject');
    _bitBlt = _gdi32.lookupFunction<BitBlt_C, BitBlt_Dart>('BitBlt');
    _deleteObject = _gdi32.lookupFunction<DeleteObject_C, DeleteObject_Dart>('DeleteObject');
    _getDIBits = _gdi32.lookupFunction<GetDIBits_C, GetDIBits_Dart>('GetDIBits');
  }

  Future<File?> capture() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory(p.join(appDocDir.path, 'AirShift', 'Screenshots'));
      
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      String fileName = 'AirShift_Snap_${DateTime.now().millisecondsSinceEpoch}.bmp';
      String filePath = p.join(screenshotDir.path, fileName);

      if (Platform.isWindows) {
        debugPrint('AirShift: Initiating Instant Win32 Screenshot...');
        final startTime = DateTime.now();

        // 1. Get Desktop DC and Screen resolution
        final Pointer<Void> hdcScreen = _getDC(nullptr);
        final int width = _getScreenWidth();
        final int height = _getScreenHeight();

        // 2. Create buffers
        final Pointer<Void> hdcMem = _createCompatibleDC(hdcScreen);
        final Pointer<Void> hbm = _createCompatibleBitmap(hdcScreen, width, height);
        _selectObject(hdcMem, hbm);

        // 3. BitBlt (Capture)
        _bitBlt(hdcMem, 0, 0, width, height, hdcScreen, 0, 0, 0x00CC0020); // SRCCOPY

        // 4. Extract pixel data
        final int dataSize = width * height * 4;
        final Pointer<Uint8> pPixels = calloc<Uint8>(dataSize);
        
        // Setup BITMAPINFOHEADER manually
        final Pointer<Uint8> bmi = calloc<Uint8>(40);
        bmi.asTypedList(40).setAll(0, Uint8List(40));
        ByteData.view(bmi.asTypedList(40).buffer).setUint32(0, 40, Endian.little); // biSize
        ByteData.view(bmi.asTypedList(40).buffer).setInt32(4, width, Endian.little); // biWidth
        ByteData.view(bmi.asTypedList(40).buffer).setInt32(8, -height, Endian.little); // biHeight (negative for top-down)
        ByteData.view(bmi.asTypedList(40).buffer).setUint16(12, 1, Endian.little); // biPlanes
        ByteData.view(bmi.asTypedList(40).buffer).setUint16(14, 32, Endian.little); // biBitCount

        _getDIBits(hdcMem, hbm, 0, height, pPixels.cast<Void>(), bmi.cast<Void>(), 0); // DIB_RGB_COLORS

        // 5. Construct BMP file content
        final int fileSize = 14 + 40 + dataSize;
        final Uint8List bmpData = Uint8List(fileSize);
        final ByteData bd = ByteData.view(bmpData.buffer);

        // File Header (14 bytes)
        bd.setUint8(0, 0x42); // 'B'
        bd.setUint8(1, 0x4D); // 'M'
        bd.setUint32(2, fileSize, Endian.little);
        bd.setUint32(6, 0, Endian.little); // reserved
        bd.setUint32(10, 54, Endian.little); // offset

        // Info Header (40 bytes)
        bmpData.setRange(14, 54, bmi.asTypedList(40));

        // Pixels
        bmpData.setRange(54, fileSize, pPixels.asTypedList(dataSize));

        // 6. Save
        await File(filePath).writeAsBytes(bmpData);

        // Cleanup
        calloc.free(pPixels);
        calloc.free(bmi);
        _deleteObject(hbm);
        _deleteObject(hdcMem);
        _releaseDC(nullptr, hdcScreen);

        final duration = DateTime.now().difference(startTime);
        debugPrint('AirShift: Instant Win32 Screenshot successful in ${duration.inMilliseconds}ms: $filePath');
        return File(filePath);
      } else {
        final savedPath = await screenshotController.captureAndSave(
          screenshotDir.path,
          fileName: fileName.replaceAll('.bmp', '.png'),
        );
        return savedPath != null ? File(savedPath) : null;
      }
    } catch (e) {
      debugPrint('Screenshot Error: $e');
      return null;
    }
  }

  int _getScreenWidth() {
    final GetSystemMetrics_Dart getSystemMetrics = _user32.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');
    return getSystemMetrics(0); // SM_CXSCREEN
  }

  int _getScreenHeight() {
    final GetSystemMetrics_Dart getSystemMetrics = _user32.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');
    return getSystemMetrics(1); // SM_CYSCREEN
  }
}

typedef GetSystemMetrics_Dart = int Function(int nIndex);
