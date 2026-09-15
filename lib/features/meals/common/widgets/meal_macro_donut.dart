import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/analysis_chart_colors.dart';

/// Energy proportions (4/4/9). An unknown or empty composition stays neutral.
class MealMacroDonut extends StatelessWidget {
  final double? netCarbs;
  final double? protein;
  final double? fat;

  const MealMacroDonut({
    super.key,
    required this.netCarbs,
    required this.protein,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final macros = [netCarbs, protein, fat];
    final valid = macros.every((v) => v != null && v.isFinite && v >= 0);
    final energy = valid ? [netCarbs! * 4, protein! * 4, fat! * 9] : <double>[];
    final total = energy.fold(0.0, (sum, value) => sum + value);
    final palette = AnalysisChartColors(Theme.of(context).brightness);
    final colors = [palette.carbs, palette.protein, palette.fat];
    return ExcludeSemantics(
      child: SizedBox(
        width: 112,
        height: 112,
        child: PieChart(
          PieChartData(
            centerSpaceRadius: 29,
            sectionsSpace: 3,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(enabled: false),
            sections: total > 0 && total.isFinite
                ? [
                    for (var i = 0; i < energy.length; i++)
                      if (energy[i] > 0)
                        PieChartSectionData(
                          value: energy[i],
                          color: colors[i],
                          radius: 24,
                          showTitle: false,
                        ),
                  ]
                : [
                    PieChartSectionData(
                      value: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                      radius: 24,
                      showTitle: false,
                    ),
                  ],
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}
