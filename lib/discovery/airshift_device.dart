class AirShiftDevice {
  final String sessionName;
  final String ipAddress;
  final int port;
  final String? thumbprint;
  int? rssi;

  AirShiftDevice({
    required this.sessionName,
    required this.ipAddress,
    required this.port,
    this.thumbprint,
    this.rssi,
  });

  @override
  String toString() => 'AirShiftDevice($sessionName, $ipAddress:$port, rssi: $rssi)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirShiftDevice &&
          runtimeType == other.runtimeType &&
          sessionName == other.sessionName &&
          ipAddress == other.ipAddress;

  @override
  int get hashCode => sessionName.hashCode ^ ipAddress.hashCode;
}
