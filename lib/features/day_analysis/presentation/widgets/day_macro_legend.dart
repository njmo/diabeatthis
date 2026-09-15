import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/chart_color_label.dart';
import '../../../meals/common/theme/analysis_chart_colors.dart';
import '../formatters/day_stat_formatter.dart';

class DayMacroLegend extends StatelessWidget {
  final double? netCarbs;
  final double? protein;
  final double? fat;

  const DayMacroLegend({
    super.key,
    required this.netCarbs,
    required this.protein,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final colors = AnalysisChartColors(Theme.of(context).brightness);
    final items = [
      (label: lang.dayCarbs, value: netCarbs, color: colors.carbs),
      (label: lang.dayProtein, value: protein, color: colors.protein),
      (label: lang.dayFat, value: fat, color: colors.fat),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ChartColorLabel(
                    color: items[i].color,
                    label: items[i].label,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  format.grams(items[i].value),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
