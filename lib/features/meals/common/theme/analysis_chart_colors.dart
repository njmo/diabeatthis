import 'package:flutter/material.dart';

import '../../../../common/theme/glucose_range_colors.dart';

/// Dedicated chart colors: app theme accents may be nearly identical.
class AnalysisChartColors extends GlucoseRangeColors {
  const AnalysisChartColors(super.brightness);

  Color get carbs => isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
  Color get protein =>
      isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2);
  Color get fat => isDark ? const Color(0xFFFFB74D) : const Color(0xFFB85B00);
}
