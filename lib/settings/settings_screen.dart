import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AirShiftSettings.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirShiftColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings', style: AirShiftTypography.emphasis),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection('General', [
            _buildToggleTile(
              'Haptic Feedback',
              'Subtle vibrations during gestures',
              _settings.hapticFeedback,
              (val) => setState(() {
                _settings.hapticFeedback = val;
                _settings.save();
              }),
            ),
            _buildTile(
              'Custom Save Location',
              _settings.customSavePath ?? 'Using smart defaults',
              Icons.folder_open,
              () {
                // Future: Pick directory
              },
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Privacy', [
            _buildToggleTile(
              'Start When Detect',
              'Silently activate when a device is nearby',
              _settings.startWhenDetect,
              (val) => setState(() {
                _settings.startWhenDetect = val;
                _settings.save();
              }),
            ),
          ]),
          const SizedBox(height: 24),
          _buildSection('Permissions', [
            _buildPermissionTile('Camera / Gesture Engine', Permission.camera),
            _buildPermissionTile('Overlay Window', Permission.systemAlertWindow),
            _buildPermissionTile('Nearby Devices (BLE)', Permission.bluetoothScan),
          ]),
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AirShiftColors.bluePrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AirShiftColors.bluePrimary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, color: AirShiftColors.bluePrimary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'ZERO CLOUD PRIVACY',
                        style: AirShiftTypography.label.copyWith(
                          color: AirShiftColors.bluePrimary,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Air Shift v1.0.0',
                  style: TextStyle(color: AirShiftColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AirShiftTypography.label.copyWith(
              color: AirShiftColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AirShiftColors.glassSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AirShiftColors.glassBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: AirShiftColors.textSecondary, fontSize: 13)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AirShiftColors.bluePrimary,
      ),
    );
  }

  Widget _buildTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AirShiftColors.textSecondary),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      subtitle: Text(subtitle, style: TextStyle(color: AirShiftColors.textSecondary, fontSize: 13)),
      onTap: onTap,
    );
  }

  Widget _buildPermissionTile(String title, Permission permission) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final isGranted = snapshot.data?.isGranted ?? false;
        return ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          trailing: Text(
            isGranted ? 'ACTIVE' : 'DISABLED',
            style: TextStyle(
              color: isGranted ? AirShiftColors.greenConfirm : Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            if (!isGranted) {
               await permission.request();
               setState(() {});
            }
          },
        );
      },
    );
  }
}
