import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../settings/settings_model.dart';

class SelectionRing extends StatefulWidget {
  final Offset position;
  final bool isCompleted;
  final VoidCallback onComplete;

  const SelectionRing({
    super.key,
    required this.position,
    this.isCompleted = false,
    required this.onComplete,
  });

  @override
  State<SelectionRing> createState() => _SelectionRingState();
}

class _SelectionRingState extends State<SelectionRing> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Offset? _lastPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AirShiftMotion.selectionFill,
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (AirShiftSettings.instance.hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        widget.onComplete();
      }
    });
    _lastPosition = widget.position;
    _controller.forward();
  }

  @override
  void didUpdateWidget(SelectionRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Jitter tolerance: 10px
    if ((widget.position - _lastPosition!).distance > 10) {
      _controller.reset();
      _controller.forward();
      _lastPosition = widget.position;
    }

    if (widget.isCompleted) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 30,
      top: widget.position.dy - 30,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: RingPainter(
              progress: 1.0 - _animation.value,
              isCompleted: widget.isCompleted,
            ),
            size: const Size(60, 60),
          );
        },
      ),
    );
  }
}

class RingPainter extends CustomPainter {
  final double progress;
  final bool isCompleted;

  RingPainter({required this.progress, required this.isCompleted});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = isCompleted ? AirShiftColors.bluePrimary : AirShiftColors.bluePrimary.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (!isCompleted) {
      // Draw background ring (dim)
      canvas.drawCircle(center, radius, paint..color = paint.color.withOpacity(0.2));
      
      // Draw shrinking ring
      final shrinkingRadius = radius * (1.0 - progress);
      canvas.drawCircle(center, shrinkingRadius, paint..color = AirShiftColors.bluePrimary);
    } else {
      // Solid outline
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RingPainter oldDelegate) => 
    oldDelegate.progress != progress || oldDelegate.isCompleted != isCompleted;
}
