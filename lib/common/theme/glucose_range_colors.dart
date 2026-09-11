import 'package:flutter/material.dart';

/// Consistent range colors across meal and day analysis.
class GlucoseRangeColors {
  final bool isDark;
  const GlucoseRangeColors(Brightness brightness)
    : isDark = brightness == Brightness.dark;

  Color get inRange =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF21864A);
  Color get aboveRange =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFB85B00);
  Color get belowRange =>
      isDark ? const Color(0xFFFB7185) : const Color(0xFFC62828);
  Color get missing =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
}
