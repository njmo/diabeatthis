import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import 'meal_detail_formatters.dart';

class MealOutcomeDetails extends StatelessWidget {
  final GlucoseWindowSummary summary;

  const MealOutcomeDetails({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final returned = summary.firstReturnAfterPeak;
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: Text(
        messages.mealGlucoseAnalysisTitle,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      children: [
        ResponsiveMetricList(
          maxColumns: 2,
          children: [
            AnalysisMetric(
              label: messages.mealReviewMinimum,
              value: formatMgdl(summary.minimum?.sgv),
              detail: summary.minimum == null
                  ? null
                  : mealTime(summary.minimum!.date),
            ),
            if ((summary.peak?.sgv ?? 0) > 180)
              AnalysisMetric(
                label: messages.mealReviewReturn,
                value: returned == null ? '—' : mealTime(returned.date),
                detail: returned == null
                    ? messages.mealReviewNoReturn
                    : formatDurationOffset(
                        returned.date.difference(summary.start),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(messages.mealReviewContext),
        const SizedBox(height: 12),
        Text(
          messages.mealReviewMethod,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
