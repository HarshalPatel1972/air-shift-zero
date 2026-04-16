import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;
import 'airshift_device.dart';

class AirShiftMdnsService {
  nsd.Registration? _registration;
  nsd.Discovery? _discovery;
  final _devicesController = StreamController<List<AirShiftDevice>>.broadcast();
  final Map<String, AirShiftDevice> _discoveredDevices = {};

  Stream<List<AirShiftDevice>> get devicesStream => _devicesController.stream;

  Future<void> startAnnouncing(String sessionName, int port, {String? thumbprint}) async {
    _registration = await nsd.register(nsd.Service(
      name: sessionName,
      type: '_airshift._tcp',
      port: port,
      txt: thumbprint != null ? {'thumb': Uint8List.fromList(utf8.encode(thumbprint))} : null,
    ));
  }

  Future<void> stopAnnouncing() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
  }

  Future<void> startDiscovery() async {
    _discovery = await nsd.startDiscovery('_airshift._tcp');
    _discovery?.addListener(() {
      _updateDevices(_discovery!.services);
    });
  }

  void _updateDevices(List<nsd.Service> services) {
    for (var service in services) {
      if (service.name == null) continue;
      
      // Filter out self
      if (_registration != null && service.name == _registration?.service.name) continue;

      // Extract IP (Simplified for now, nsd usually provides it after resolution)
      String? ip;
      if (service.addresses != null && service.addresses!.isNotEmpty) {
        ip = service.addresses!.first.address;
      }

      if (ip != null) {
        final thumb = service.txt != null && service.txt!['thumb'] != null 
            ? utf8.decode(service.txt!['thumb']!) 
            : null;
        final device = AirShiftDevice(
          sessionName: service.name!,
          ipAddress: ip,
          port: service.port ?? 49317,
          thumbprint: thumb,
        );
        _discoveredDevices[service.name!] = device;
      }
    }
    _devicesController.add(_discoveredDevices.values.toList());
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  void dispose() {
    stopAnnouncing();
    stopDiscovery();
    _devicesController.close();
  }
}
