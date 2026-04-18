import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../session/session_state.dart';

class GestureIndicator extends StatelessWidget {
  final Gesture gesture;
  final String? gestureName;

  const GestureIndicator({
    super.key,
    required this.gesture,
    this.gestureName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AirShiftColors.glassSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AirShiftColors.bluePrimary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AirShiftColors.bluePrimary.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGestureIcon(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GESTURE DETECTED',
                style: AirShiftTypography.label.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AirShiftColors.textSecondary,
                ),
              ),
              Text(
                (gestureName ?? _getGestureLabel()).toUpperCase(),
                style: AirShiftTypography.emphasis.copyWith(
                  fontSize: 16,
                  color: AirShiftColors.bluePrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGestureIcon() {
    IconData iconData;
    Color iconColor = AirShiftColors.bluePrimary;

    switch (gesture) {
      case Gesture.fist:
        iconData = Icons.pan_tool_alt; // Representing a closed hand/grab
        break;
      case Gesture.openPalm:
        iconData = Icons.front_hand;
        break;
      case Gesture.victory:
        iconData = Icons.vibration; // Representing victory/peace
        break;
      case Gesture.singleFinger:
        iconData = Icons.touch_app;
        break;
      case Gesture.none:
      default:
        iconData = Icons.do_not_disturb_on;
        iconColor = AirShiftColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  String _getGestureLabel() {
    switch (gesture) {
      case Gesture.fist:
        return 'Fist';
      case Gesture.openPalm:
        return 'Open Palm';
      case Gesture.victory:
        return 'Victory';
      case Gesture.singleFinger:
        return 'Pointer';
      case Gesture.none:
      default:
        return 'Searching...';
    }
  }
}
