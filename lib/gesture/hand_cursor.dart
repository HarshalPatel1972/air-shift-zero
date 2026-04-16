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
    return Positioned(
      left: widget.x - 30,
      top: widget.y - 30,
      child: AnimatedBuilder(
        animation: _morphAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(60, 60),
            painter: _HandPainter(
              morphProgress: _morphAnimation.value,
              color: widget.isFist ? AirShiftColors.greenConfirm : AirShiftColors.bluePrimary,
            ),
          );
        },
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  final double morphProgress; // 0.0 = Open, 1.0 = Fist
  final Color color;

  _HandPainter({required this.morphProgress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Draw Shadow
    canvas.drawCircle(center + const Offset(0, 4), size.width / 3, shadowPaint);

    // Cinematic 3D Hand Logic
    // In a real app, we'd draw paths for palm and fingers.
    // For this premium reconstruction, we'll use a morphing circle-to-rounded-rect
    // that represents the core of the hand movement.
    
    final mainRadius = (size.width / 3) * (1.0 - (morphProgress * 0.2));
    final rectSide = size.width / 2.5;
    
    if (morphProgress < 0.1) {
      // Open Palm state
      canvas.drawCircle(center, mainRadius, paint);
      // Small finger indicators
      for (var i = 0; i < 5; i++) {
        final angle = -2.3 + (i * 0.5);
        final fX = center.dx + (mainRadius * 1.5) * (i == 0 ? 0.8 : 1.0) * (i == 4 ? 0.8 : 1.0) * (i == 2 ? 1.2 : 1.0) * 0.8 * (i == 1 || i == 3 ? 1.1 : 1.0) * (i == 0 ? 0.7 : 1.0) * (i == 4 ? 0.7 : 1.0) * (i == 2 ? 1.4 : 1.0) * 0.5; // Mocking finger lengths
        // We actally use a more descriptive approach:
        final fingerTip = center + Offset.fromDirection(angle, mainRadius * 1.6);
        canvas.drawCircle(fingerTip, 4, paint);
        canvas.drawLine(center, fingerTip, paint..strokeWidth = 6..style = PaintingStyle.stroke);
        paint.style = PaintingStyle.fill;
      }
    } else {
      // Morphing to Fist
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: rectSide, height: rectSide),
        Radius.circular(rectSide / (2 - morphProgress)),
      );
      canvas.drawRRect(rrect, paint);
    }
    
    // Core Glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, mainRadius, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _HandPainter oldDelegate) =>
      oldDelegate.morphProgress != morphProgress || oldDelegate.color != color;
}
