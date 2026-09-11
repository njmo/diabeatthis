import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../common/theme/analysis_chart_colors.dart';
import '../../../common/widgets/glucose_range_bar.dart';
import 'meal_range_legend_item.dart';

class MealRangeSummary extends StatelessWidget {
  final GlucoseWindowSummary summary;

  const MealRangeSummary({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String percent(Duration duration) {
      final value = summary.percent(duration);
      return value == null
          ? '—'
          : '${NumberFormat('0.#', messages.localeName).format(value)}%';
    }

    final palette = AnalysisChartColors(theme.brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              percent(summary.inRange),
              style: theme.textTheme.headlineMedium,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.mealTimeInRangeLabel,
                  style: theme.textTheme.labelLarge,
                ),
                Text(
                  '70–180 mg/dl · ${formatDurationLabel(summary.inRange)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          messages.mealRangeObservedBasis,
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 14),
        Semantics(
          label: '${messages.mealReviewRange}: ${percent(summary.inRange)}',
          child: GlucoseRangeBar(summary: summary, height: 12),
        ),
        const SizedBox(height: 16),
        ResponsiveMetricList(
          maxColumns: 2,
          minimumWidth: 110,
          children: [
            MealRangeLegendItem(
              color: palette.aboveRange,
              label: messages.mealReviewAbove,
              value:
                  '${percent(summary.aboveRange)} · ${formatDurationLabel(summary.aboveRange)}',
            ),
            MealRangeLegendItem(
              color: palette.belowRange,
              label: messages.mealReviewBelow,
              value:
                  '${percent(summary.belowRange)} · ${formatDurationLabel(summary.belowRange)}',
            ),
          ],
        ),
        if (summary.missing > Duration.zero) ...[
          const SizedBox(height: 14),
          MealRangeLegendItem(
            color: palette.missing,
            label: messages.mealReviewMissing,
            value: formatDurationLabel(summary.missing),
          ),
        ],
      ],
    );
  }
}
