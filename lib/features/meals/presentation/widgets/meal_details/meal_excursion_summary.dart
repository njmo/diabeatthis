import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import 'meal_detail_formatters.dart';

class MealExcursionSummary extends StatelessWidget {
  final GlucoseWindowSummary summary;

  const MealExcursionSummary({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final above = summary.firstAboveRange;
    if (above == null) return const SizedBox.shrink();
    final returned = summary.firstReturnAfterPeak;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: ResponsiveMetricList(
        maxColumns: 2,
        minimumWidth: 110,
        children: [
          AnalysisMetric(
            label: context.lang.mealReviewFirstAbove,
            value: mealTime(above.date),
            detail: formatDurationOffset(above.date.difference(summary.start)),
          ),
          AnalysisMetric(
            label: context.lang.mealReviewFirstReturn,
            value: returned == null ? '—' : mealTime(returned.date),
            detail: returned == null
                ? context.lang.mealReviewNoReturn
                : formatDurationOffset(returned.date.difference(summary.start)),
          ),
        ],
      ),
    );
  }
}
