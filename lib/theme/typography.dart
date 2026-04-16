import 'package:flutter/material.dart';
import 'colors.dart';

class AirShiftTypography {
  static const String fontFamily = 'Inter'; // Fallback to system if not loaded

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AirShiftColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle emphasis = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AirShiftColors.textPrimary,
    fontFamily: fontFamily,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AirShiftColors.textSecondary,
    fontFamily: fontFamily,
  );
}
