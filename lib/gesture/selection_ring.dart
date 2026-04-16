import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';

class SelectionRing extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const SelectionRing({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<SelectionRing> createState() => _SelectionRingState();
}

class _SelectionRingState extends State<SelectionRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset? _startPosition;

  @override
  void initState() {
    super.initState();
    _startPosition = widget.position;
    _controller = AnimationController(
      vsync: this,
      duration: AirShiftMotion.selectionFill,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void didUpdateWidget(SelectionRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Phase 2 - Jitter Tolerance (10px threshold)
    if (_startPosition != null) {
      final difference = (widget.position - _startPosition!).distance;
      if (difference > 10.0) {
        _resetTimer();
      }
    }
  }

  void _resetTimer() {
    _startPosition = widget.position;
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 40,
      top: widget.position.dy - 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(80, 80),
            painter: _RingPainter(
              progress: _controller.value,
              color: AirShiftColors.bluePrimary,
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (shrinking)
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2 - 4;
    
    // The spec says shrinking from 100% to 0%
    final currentRadius = baseRadius * (1.0 - progress);

    final bgPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Outer faint ring for boundary
    canvas.drawCircle(center, baseRadius, bgPaint);

    // Shrinking active ring
    if (currentRadius > 0) {
      canvas.drawCircle(center, currentRadius, fillPaint);
      
      // Add a subtle glow at the edge of the shrinking ring
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(center, currentRadius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
