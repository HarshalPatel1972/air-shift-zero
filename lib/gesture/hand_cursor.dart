import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';

class HandCursor extends StatefulWidget {
  final bool isFist;
  final double x;
  final double y;

  const HandCursor({
    super.key,
    required this.isFist,
    required this.x,
    required this.y,
  });

  @override
  State<HandCursor> createState() => _HandCursorState();
}

class _HandCursorState extends State<HandCursor> with SingleTickerProviderStateMixin {
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: AirShiftMotion.cursorMorph,
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOut,
    );
    if (widget.isFist) _morphController.value = 1.0;
  }

  @override
  void didUpdateWidget(HandCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFist != oldWidget.isFist) {
      if (widget.isFist) {
        _morphController.forward();
      } else {
        _morphController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 50), // Smooth tracking
      left: widget.x - 40,
      top: widget.y - 40,
      child: CustomPaint(
        painter: HandPainter(
          morphValue: _morphAnimation.value,
          isFist: widget.isFist,
        ),
        size: const Size(80, 80),
      ),
    );
  }
}

class HandPainter extends CustomPainter {
  final double morphValue;
  final bool isFist;

  HandPainter({required this.morphValue, required this.isFist});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AirShiftColors.bluePrimary.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Draw shadow
    canvas.drawCircle(center + const Offset(0, 4), 20, shadowPaint);

    // Draw hand base (simplified 3D style)
    // In a real app, this would use more complex paths or a Lottie animation
    // Here I represent it with a morphing shape
    final radius = lerpDouble(25, 20, morphValue)!;
    canvas.drawCircle(center, radius, paint);

    // Draw fingers (simplified)
    if (morphValue < 0.5) {
      // Fingers extended
      for (int i = 0; i < 5; i++) {
        final angle = (i * 0.4) - 0.8 - (pi / 2);
        final fingerTip = center + Offset(cos(angle), sin(angle)) * (25 + (1 - morphValue) * 15);
        canvas.drawCircle(fingerTip, 6, paint);
      }
    } else {
      // Fist
      paint.color = AirShiftColors.greenConfirm.withOpacity(morphValue); // Transition to green if confirmed? 
      // Actually SKILL.md says ALL selected outlines transition to green.
      // The cursor itself might stay blue or morph its shape.
    }
  }

  double? lerpDouble(num a, num b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(HandPainter oldDelegate) => 
    oldDelegate.morphValue != morphValue || oldDelegate.isFist != isFist;
}
