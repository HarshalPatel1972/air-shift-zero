import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'airshift_device.dart';

class AirShiftBleProximity {
  static const String serviceUuid = 'fd6f'; // Example standard UUID, can be any 16-bit or 128-bit
  StreamSubscription? _scanSubscription;
  final Map<String, int> _rssiMap = {};

  void startScan() async {
    if (await FlutterBluePlus.isSupported == false) return;

    FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        // In a real implementation, we'd check for our specific service UUID in r.advertisementData.serviceUuids
        // For now, we'll store RSSI by device name if it looks like an Air Shift device
        if (r.device.platformName.isNotEmpty) {
          _rssiMap[r.device.platformName] = r.rssi;
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
    );
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  List<AirShiftDevice> applyProximity(List<AirShiftDevice> mdnsDevices) {
    for (var device in mdnsDevices) {
      if (_rssiMap.containsKey(device.sessionName)) {
        device.rssi = _rssiMap[device.sessionName];
      }
    }

    // Sort by RSSI (strongest first, nulls last)
    final sorted = List<AirShiftDevice>.from(mdnsDevices);
    sorted.sort((a, b) {
      if (a.rssi == null) return 1;
      if (b.rssi == null) return -1;
      return b.rssi!.compareTo(a.rssi!);
    });

    return sorted;
  }
}
