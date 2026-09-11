import 'package:flutter/material.dart';

/// Dedicated chart colors: app theme accents may be nearly identical.
class AnalysisChartColors {
  final bool isDark;
  const AnalysisChartColors(Brightness brightness)
    : isDark = brightness == Brightness.dark;

  Color get carbs => isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
  Color get protein =>
      isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2);
  Color get fat => isDark ? const Color(0xFFFFB74D) : const Color(0xFFB85B00);
  Color get inRange =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF21864A);
  Color get aboveRange =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFB85B00);
  Color get belowRange =>
      isDark ? const Color(0xFFFB7185) : const Color(0xFFC62828);
  Color get missing =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
}
