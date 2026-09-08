import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/history/insulin_bolus_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_icons.dart';

class MealCorrectionsSummary extends StatelessWidget {
  final MealAnalysisData analysis;

  const MealCorrectionsSummary({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final summary = InsulinBolusSummary.fromTreatments(
      treatments: analysis.treatments,
      start: analysis.mealTime,
      end: analysis.chartEnd,
    );
    final number = NumberFormat('0.##', messages.localeName);
    String value(int count, double units) =>
        messages.mealReviewCorrectionsValue(count, number.format(units));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${messages.mealReviewCorrectionsTotal}: ${value(summary.count, summary.units)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ResponsiveMetricList(
          maxColumns: 2,
          children: [
            AnalysisMetric(
              icon: mealTimelineEventIcon(
                MealTimelineEventType.manualCorrection,
              ),
              label: messages.mealReviewManualCorrections,
              value: value(summary.manualCount, summary.manualUnits),
            ),
            AnalysisMetric(
              icon: mealTimelineEventIcon(MealTimelineEventType.correction),
              label: messages.mealReviewOtherCorrections,
              value: value(summary.otherCount, summary.otherUnits),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          messages.mealReviewCorrectionsWindow,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
