import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../session/airshift_session.dart';
import '../discovery/airshift_device.dart';

class DeviceRadar extends StatefulWidget {
  const DeviceRadar({super.key});

  @override
  State<DeviceRadar> createState() => _DeviceRadarState();
}

class _DeviceRadarState extends State<DeviceRadar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final _session = AirShiftSession.instance;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AirShiftDevice>>(
      stream: _session.nearbyDevices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing rings
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  double progress = (_pulseController.value + (index / 3)) % 1.0;
                  return Container(
                    width: progress * 400,
                    height: progress * 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AirShiftColors.bluePrimary.withOpacity(1.0 - progress),
                        width: 1,
                      ),
                    ),
                  );
                },
              );
            }),

            // Center 'Self' Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AirShiftColors.bluePrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 32),
            ),

            // Discovered Devices
            ...List.generate(devices.length, (index) {
              final device = devices[index];
              // Position devices in a circle around the center
              double angle = (index * (2 * math.pi / math.max(devices.length, 1)));
              double radius = 120.0;
              
              return Positioned(
                left: 200 + radius * math.cos(angle) - 30,
                top: 200 + radius * math.sin(angle) - 30,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AirShiftColors.glassSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AirShiftColors.bluePrimary, width: 2),
                      ),
                      child: const Icon(Icons.smartphone, color: AirShiftColors.textPrimary, size: 24),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.sessionName,
                      style: AirShiftTypography.label.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              );
            }),
            
            if (devices.isEmpty)
              Positioned(
                bottom: 20,
                child: Text(
                  'Scanning for nearby devices...',
                  style: AirShiftTypography.label.copyWith(color: AirShiftColors.textSecondary),
                ),
              ),
          ],
        );
      },
    );
  }
}
