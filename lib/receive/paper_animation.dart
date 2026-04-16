import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';

enum PaperState { arriving, transferring, unwrapping, open }

class PaperAnimation extends StatefulWidget {
  final PaperState state;
  final Widget? child;

  const PaperAnimation({
    super.key,
    required this.state,
    this.child,
  });

  @override
  State<PaperAnimation> createState() => _PaperAnimationState();
}

class _PaperAnimationState extends State<PaperAnimation> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _unwrapController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _unwrapAnimation;

  @override
  void initState() {
    super.initState();
    
    // Phase 6 - Breathing Pulse (1.5s infinite)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Phase 6 - Peel-Open Unwrap (400ms)
    _unwrapController = AnimationController(
      vsync: this,
      duration: AirShiftMotion.paperUnwrap,
    );
    _unwrapAnimation = CurvedAnimation(
      parent: _unwrapController, 
      curve: Curves.easeOutCubic,
    );

    _updateState(widget.state);
  }

  void _updateState(PaperState state) {
    if (state == PaperState.transferring) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }

    if (state == PaperState.unwrapping) {
      _unwrapController.forward();
    } else if (state == PaperState.arriving) {
      _unwrapController.reset();
    }
  }

  @override
  void didUpdateWidget(PaperAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _updateState(widget.state);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _unwrapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _unwrapAnimation]),
      builder: (context, child) {
        return Center(
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: CustomPaint(
              size: const Size(280, 400),
              painter: _CellophanePainter(
                unwrapProgress: _unwrapAnimation.value,
                state: widget.state,
              ),
              child: widget.state == PaperState.open 
                  ? widget.child 
                  : Opacity(
                      opacity: _unwrapAnimation.value, 
                      child: widget.child
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _CellophanePainter extends CustomPainter {
  final double unwrapProgress;
  final PaperState state;

  _CellophanePainter({required this.unwrapProgress, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    if (state == PaperState.open) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08 * (1.0 - unwrapProgress))
      ..style = PaintingStyle.fill;

    // The "Cellophane" look - very faint white with a slight sheen
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(rrect, paint);

    // Border sheen
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15 * (1.0 - unwrapProgress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(rrect, borderPaint);

    // unwrapping peel logic (Beziers)
    if (unwrapProgress > 0) {
      final peelPaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.fill;
        
      final path = Path();
      path.moveTo(size.width, 0);
      path.lineTo(size.width - (size.width * unwrapProgress), 0);
      path.quadraticBezierTo(
        size.width - (size.width * unwrapProgress * 0.5),
        size.height * unwrapProgress * 0.5,
        size.width,
        size.height * unwrapProgress,
      );
      path.close();
      canvas.drawPath(path, peelPaint);
    }
    
    // Add subtle mesh glow if transferring
    if (state == PaperState.transferring) {
       final glowPaint = Paint()
        ..color = AirShiftColors.bluePrimary.withOpacity(0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
       canvas.drawRRect(rrect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CellophanePainter oldDelegate) =>
      oldDelegate.unwrapProgress != unwrapProgress || oldDelegate.state != state;
}
