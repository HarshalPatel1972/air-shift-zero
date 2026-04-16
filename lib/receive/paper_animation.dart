import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/motion.dart';

enum PaperState { arriving, pulse, unwrap, open }

class AirShiftPaperAnimation extends StatefulWidget {
  final PaperState state;
  final Widget? child;

  const AirShiftPaperAnimation({
    super.key, 
    required this.state,
    this.child,
  });

  @override
  State<AirShiftPaperAnimation> createState() => _AirShiftPaperAnimationState();
}

class _AirShiftPaperAnimationState extends State<AirShiftPaperAnimation> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _unwrapController;
  late Animation<double> _pulseScale;
  late Animation<double> _unwrapProgress;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _unwrapController = AnimationController(
        vsync: this, duration: AirShiftMotion.paperUnwrap);
    _unwrapProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _unwrapController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(AirShiftPaperAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == PaperState.unwrap && oldWidget.state != PaperState.unwrap) {
      _unwrapController.forward();
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
      animation: Listenable.merge([_pulseController, _unwrapController]),
      builder: (context, child) {
        final scale = widget.state == PaperState.pulse ? _pulseScale.value : 1.0;
        
        return Center(
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: CellophanePainter(
                unwrapProgress: widget.state == PaperState.unwrap ? _unwrapProgress.value : 0.0,
                isWrapped: widget.state != PaperState.open,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
                child: widget.state == PaperState.open ? widget.child : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CellophanePainter extends CustomPainter {
  final double unwrapProgress;
  final bool isWrapped;

  CellophanePainter({required this.unwrapProgress, required this.isWrapped});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isWrapped && unwrapProgress == 1.0) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // The "Paper" shape
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ));

    if (unwrapProgress > 0) {
      // Corner peeling logic: Subtract a triangle/arc from the top-right
      final peelPath = Path()
        ..moveTo(size.width, 0)
        ..lineTo(size.width - (size.width * unwrapProgress * 1.5), 0)
        ..lineTo(size.width, size.height * unwrapProgress * 1.5)
        ..close();
      
      canvas.drawPath(
        Path.combine(PathOperation.difference, path, peelPath), 
        paint
      );
      canvas.drawPath(
        Path.combine(PathOperation.difference, path, peelPath), 
        borderPaint
      );
    } else {
      canvas.drawPath(path, paint);
      canvas.drawPath(path, borderPaint);
    }
    
    // Subtle cellophane gloss highlights
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.3, 0.5, 0.7],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawPath(path, glossPaint);
  }

  @override
  bool shouldRepaint(CellophanePainter oldDelegate) => 
      oldDelegate.unwrapProgress != unwrapProgress || oldDelegate.isWrapped != isWrapped;
}
