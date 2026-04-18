import 'dart:ui';
import 'dart:math' as math;
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

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final _settings = AirShiftSettings.instance;
  late AnimationController _meshController;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
  }

  @override
  void dispose() {
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Mesh Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _meshController,
              builder: (context, _) => CustomPaint(
                painter: SettingsMeshPainter(progress: _meshController.value),
              ),
            ),
          ),
          
          // 2. Glass Surface
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),

          // 3. Content
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('PREFERENCES', style: TextStyle(letterSpacing: 4, fontSize: 13, fontWeight: FontWeight.bold)),
                centerTitle: true,
                floating: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('CORE ENGINE'),
                    _buildPremiumGroup([
                      _buildSettingsTile(
                        'Haptic Feedback',
                        'Neural pulse on gesture detection',
                        Icons.vibration_rounded,
                        _settings.hapticFeedback,
                        (val) => setState(() {
                          _settings.hapticFeedback = val;
                          _settings.save();
                        }),
                      ),
                      _buildSettingsTile(
                        'Zero-Touch Discovery',
                        'Automatic peer synchronization',
                        Icons.auto_awesome_mosaic_rounded,
                        _settings.startWhenDetect,
                        (val) => setState(() {
                          _settings.startWhenDetect = val;
                          _settings.save();
                        }),
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildSectionHeader('PERMISSIONS'),
                    _buildPremiumGroup([
                      _buildPermissionTile('Neural Hand Tracker', Permission.camera),
                      _buildPermissionTile('Local Mesh Discovery', Permission.location),
                    ]),
                    const SizedBox(height: 60),
                    _buildFooter(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 16),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildPremiumGroup(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AirShiftColors.bluePrimary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AirShiftColors.bluePrimary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: _buildPremiumSwitch(value, onChanged),
    );
  }

  Widget _buildPermissionTile(String title, Permission permission) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final isGranted = snapshot.data?.isGranted ?? false;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          subtitle: Text(
            isGranted ? 'ACTIVE STATUS: AUTHORIZED' : 'STATUS: RESTRICTED',
            style: TextStyle(
              color: isGranted ? AirShiftColors.greenConfirm.withOpacity(0.6) : Colors.redAccent.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          trailing: _buildPremiumSwitch(isGranted, (val) async {
             if (!isGranted) {
               await permission.request();
               setState(() {});
             }
          }),
        );
      },
    );
  }

  Widget _buildPremiumSwitch(bool value, Function(bool) onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value ? AirShiftColors.bluePrimary.withOpacity(0.2) : Colors.white12,
          border: Border.all(color: value ? AirShiftColors.bluePrimary.withOpacity(0.5) : Colors.white10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? AirShiftColors.bluePrimary : Colors.white24,
              boxShadow: value ? [BoxShadow(color: AirShiftColors.bluePrimary.withOpacity(0.5), blurRadius: 10)] : [],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Icon(Icons.verified_user_rounded, color: Colors.white24, size: 32),
        const SizedBox(height: 16),
        const Text('AIR SHIFT ZERO v1.0', style: TextStyle(color: Colors.white24, letterSpacing: 5, fontSize: 10, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('SECURE NEURAL BRIDGING ACTIVE', style: TextStyle(color: AirShiftColors.greenConfirm.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ],
    );
  }
}

class SettingsMeshPainter extends CustomPainter {
  final double progress;
  SettingsMeshPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final t = progress * 2 * math.pi;
    
    void drawBlob(Offset center, double radius, Color color) {
       final gradient = RadialGradient(colors: [color.withOpacity(0.12), Colors.transparent]);
       paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
       canvas.drawCircle(center, radius, paint);
    }

    drawBlob(Offset(size.width * 0.8 + math.sin(t) * 80, size.height * 0.2 + math.cos(t) * 80), 300, const Color(0xFF9013FE));
    drawBlob(Offset(size.width * 0.2 + math.cos(t) * 60, size.height * 0.8 + math.sin(t) * 60), 400, const Color(0xFF4A90E2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
