import 'dart:math' as math;

import 'package:diabeatthis/features/meals/common/theme/analysis_chart_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    test(
      'chart colors stay distinct and contrast with $brightness surfaces',
      () {
        final palette = AnalysisChartColors(brightness);
        final macro = [palette.carbs, palette.protein, palette.fat];
        final range = [
          palette.inRange,
          palette.aboveRange,
          palette.belowRange,
          palette.missing,
        ];
        expect(macro.toSet().length, 3);
        expect(range.toSet().length, 4);
        final scheme = ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        );
        for (final background in [scheme.surface, scheme.surfaceContainerLow]) {
          for (final color in [...macro, ...range]) {
            final a = color.computeLuminance();
            final b = background.computeLuminance();
            expect(
              (math.max(a, b) + .05) / (math.min(a, b) + .05),
              greaterThanOrEqualTo(3),
            );
          }
        }
      },
    );
  }
}
