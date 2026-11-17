import 'package:flutter/material.dart';

/// Consistent range colors across meal and day analysis.
class GlucoseRangeColors {
  final bool isDark;
  const GlucoseRangeColors(Brightness brightness)
    : isDark = brightness == Brightness.dark;

  Color get inRange =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  Color get aboveRange =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get belowRange =>
      isDark ? const Color(0xFFFB7185) : const Color(0xFFDC2626);
  Color get missing =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
}
