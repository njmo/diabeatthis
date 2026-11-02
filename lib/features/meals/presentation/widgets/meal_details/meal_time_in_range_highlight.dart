import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_highlight_panel.dart';
import '../../../../../common/widgets/glucose_range_bar.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../common/theme/analysis_chart_colors.dart';
import 'meal_range_legend_item.dart';

class MealTimeInRangeHighlight extends StatelessWidget {
  const MealTimeInRangeHighlight({super.key, required this.summary});
  final GlucoseWindowSummary summary;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final percent = summary.percent(summary.inRange);
    final colors = AnalysisChartColors(Theme.of(context).brightness);
    return AnalysisHighlightPanel(
      title: lang.mealTimeInRangeLabel,
      subtitle: '70–180 mg/dl',
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              percent == null
                  ? '—'
                  : '${NumberFormat('0.#', lang.localeName).format(percent)}%',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              formatDurationLabel(summary.inRange),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GlucoseRangeBar(summary: summary, height: 14),
            const SizedBox(height: 12),
            ResponsiveMetricList(
              maxColumns: 2,
              minimumWidth: 100,
              children: [
                MealRangeLegendItem(
                  color: colors.belowRange,
                  label: lang.mealReviewBelow,
                  value: formatDurationLabel(summary.belowRange),
                ),
                MealRangeLegendItem(
                  color: colors.aboveRange,
                  label: lang.mealReviewAbove,
                  value: formatDurationLabel(summary.aboveRange),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              lang.mealRangeObservedBasis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
