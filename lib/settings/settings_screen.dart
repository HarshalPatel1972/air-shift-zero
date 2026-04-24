import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/colors.dart';
import 'settings_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _settings = AirShiftSettings.instance;
  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 18))
      ..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: Stack(
        children: [
          // ── Animated background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => CustomPaint(
                painter: _SettingsBgPainter(t: _bgCtrl.value),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                  color: const Color(0xFF06060A).withOpacity(0.55)),
            ),
          ),

          // ── Content ──
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: _backBtn(context),
                title: Text('PREFERENCES',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withOpacity(0.6),
                    )),
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _sectionLabel('CORE ENGINE'),
                    _glassGroup([
                      _toggleTile(
                        icon: Icons.vibration_rounded,
                        title: 'Haptic Feedback',
                        subtitle: 'Pulse on gesture detection',
                        value: _settings.hapticFeedback,
                        onChanged: (v) => setState(() {
                          _settings.hapticFeedback = v;
                          _settings.save();
                        }),
                      ),
                      _divider(),
                      _toggleTile(
                        icon: Icons.auto_awesome_mosaic_rounded,
                        title: 'Auto Discovery',
                        subtitle: 'Start when peers are nearby',
                        value: _settings.startWhenDetect,
                        onChanged: (v) => setState(() {
                          _settings.startWhenDetect = v;
                          _settings.save();
                        }),
                      ),
                    ]),

                    const SizedBox(height: 28),
                    _sectionLabel('PERMISSIONS'),
                    _glassGroup([
                      _permTile('Camera Engine', Permission.camera),
                      _divider(),
                      _permTile('Peer Discovery', Permission.location),
                    ]),

                    const SizedBox(height: 56),
                    _footer(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── WIDGETS ─────────────────────────────────────

  Widget _backBtn(BuildContext ctx) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 14),
      child: Text(text,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.3),
          )),
    );
  }

  Widget _glassGroup(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
        height: 1,
        thickness: 1,
        indent: 72,
        color: Colors.white.withOpacity(0.04));
  }

  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AirShiftColors.purpleActive.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AirShiftColors.purpleActive, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style:
              TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
      trailing: _neoSwitch(value, onChanged),
    );
  }

  Widget _permTile(String title, Permission perm) {
    return FutureBuilder<PermissionStatus>(
      future: perm.status,
      builder: (ctx, snap) {
        final granted = snap.data?.isGranted ?? false;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (granted
                      ? AirShiftColors.greenConfirm
                      : Colors.redAccent)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              granted ? Icons.check_circle_outline : Icons.lock_outline,
              color: granted ? AirShiftColors.greenConfirm : Colors.redAccent,
              size: 20,
            ),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(
            granted ? 'AUTHORIZED' : 'RESTRICTED',
            style: TextStyle(
              color: (granted
                      ? AirShiftColors.greenConfirm
                      : Colors.redAccent)
                  .withOpacity(0.55),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          trailing: _neoSwitch(granted, (v) async {
            if (!granted) {
              await perm.request();
              setState(() {});
            }
          }),
        );
      },
    );
  }

  Widget _neoSwitch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? AirShiftColors.bluePrimary.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: value
                ? AirShiftColors.bluePrimary.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  value ? AirShiftColors.bluePrimary : Colors.white.withOpacity(0.2),
              boxShadow: value
                  ? [
                      BoxShadow(
                          color: AirShiftColors.bluePrimary.withOpacity(0.5),
                          blurRadius: 10)
                    ]
                  : [],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Icon(Icons.verified_user_rounded,
            color: Colors.white.withOpacity(0.12), size: 28),
        const SizedBox(height: 14),
        Text('AIR SHIFT ZERO',
            style: TextStyle(
              color: Colors.white.withOpacity(0.15),
              letterSpacing: 6,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 6),
        Text('v1.0.0 · Neural Bridge Active',
            style: TextStyle(
              color: Colors.white.withOpacity(0.1),
              fontSize: 10,
            )),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// Settings Background Painter
// ════════════════════════════════════════════════════════════
class _SettingsBgPainter extends CustomPainter {
  final double t;
  _SettingsBgPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final p = Paint();

    void blob(Offset c, double r, Color col) {
      p.shader = RadialGradient(
        colors: [col.withOpacity(0.1), Colors.transparent],
      ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, p);
    }

    blob(
      Offset(size.width * 0.8 + math.sin(a) * 60,
          size.height * 0.2 + math.cos(a) * 60),
      300,
      const Color(0xFF9013FE),
    );
    blob(
      Offset(size.width * 0.2 + math.cos(a) * 50,
          size.height * 0.8 + math.sin(a) * 50),
      380,
      const Color(0xFF4A90E2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
