import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../../meals/common/widgets/meal_macro_donut.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_macro_legend.dart';

/// Shared presentation of live and accepted meal totals; never reconstructs data.
class DayMealsOverview extends StatelessWidget {
  final num? mealCount;
  final double? netCarbs;
  final double? protein;
  final double? fat;
  final num? lowCount;
  final double? lowCarbs;

  const DayMealsOverview({
    super.key,
    required this.mealCount,
    required this.netCarbs,
    required this.protein,
    required this.fat,
    required this.lowCount,
    required this.lowCarbs,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final legend = DayMacroLegend(
      netCarbs: netCarbs,
      protein: protein,
      fat: fat,
    );
    final chart = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MealMacroDonut(netCarbs: netCarbs, protein: protein, fat: fat),
        const SizedBox(height: 8),
        Text(
          lang.dayMacroEnergyShare,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
    final statistics = ResponsiveMetricList(
      minimumWidth: 80,
      children: [
        AnalysisMetric(
          label: lang.dayMealsCount,
          value: format.number(mealCount, decimals: 0),
        ),
        AnalysisMetric(
          label: lang.dayLowCount,
          value: format.number(lowCount, decimals: 0),
        ),
        AnalysisMetric(label: lang.dayLowCarbs, value: format.grams(lowCarbs)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            if (constraints.maxWidth < 270 || largeText) {
              return Column(
                children: [chart, const SizedBox(height: 16), legend],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 116, child: chart),
                const SizedBox(width: 16),
                Expanded(child: legend),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        statistics,
      ],
    );
  }
}
