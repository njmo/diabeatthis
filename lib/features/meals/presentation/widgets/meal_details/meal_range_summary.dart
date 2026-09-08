import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
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

    final durations = [
      summary.inRange,
      summary.aboveRange,
      summary.belowRange,
      summary.missing,
    ];
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.error,
      scheme.outlineVariant,
    ];
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
        const SizedBox(height: 14),
        Semantics(
          label: '${messages.mealReviewRange}: ${percent(summary.inRange)}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < durations.length; i++)
                    if (durations[i].inMilliseconds > 0)
                      Expanded(
                        flex: durations[i].inMilliseconds,
                        child: ColoredBox(
                          color: colors[i],
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ResponsiveMetricList(
          maxColumns: 2,
          minimumWidth: 110,
          children: [
            MealRangeLegendItem(
              color: scheme.tertiary,
              label: messages.mealReviewAbove,
              value:
                  '${percent(summary.aboveRange)} · ${formatDurationLabel(summary.aboveRange)}',
            ),
            MealRangeLegendItem(
              color: scheme.error,
              label: messages.mealReviewBelow,
              value:
                  '${percent(summary.belowRange)} · ${formatDurationLabel(summary.belowRange)}',
            ),
          ],
        ),
        if (summary.missing > Duration.zero) ...[
          const SizedBox(height: 14),
          MealRangeLegendItem(
            color: scheme.outlineVariant,
            label: messages.mealReviewMissing,
            value: formatDurationLabel(summary.missing),
          ),
        ],
      ],
    );
  }
}
