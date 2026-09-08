import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../data/models/meal_analysis_data.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';

/// Describes recorded outcomes without inferring causes or treatment advice.
class MealReviewFindings extends StatelessWidget {
  final MealAnalysisData analysis;
  final MealDetailsData details;

  const MealReviewFindings({
    super.key,
    required this.analysis,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final messages = context.lang;
    final summary = GlucoseWindowSummary(
      readings: analysis.glucoseReadings,
      start: analysis.mealTime,
      end: analysis.chartEnd,
    );
    final peak = summary.peak;
    final returned = summary.firstReturnAfterPeak;
    final planned = details.plannedSnapshot;
    final consumed = details.consumedSnapshot;
    final findings = [
      if (peak != null)
        messages.mealReviewPeakFinding(
          formatMgdl(peak.sgv),
          formatDurationLabel(peak.date.difference(analysis.mealTime)),
        ),
      if (returned != null)
        messages.mealReviewReturnFinding(mealTime(returned.date)),
      if (planned != null &&
          consumed != null &&
          planned.totalCarbsG != consumed.totalCarbsG)
        messages.mealReviewPortionFinding(
          formatSignedGrams(consumed.totalCarbsG - planned.totalCarbsG),
        ),
      if (analysis.linkedMeals.isNotEmpty) messages.mealReviewOtherMeals,
      if (analysis.linkedActivities.isNotEmpty) messages.mealReviewActivity,
      if (summary.missing > Duration.zero)
        messages.mealReviewMissingFinding(formatDurationLabel(summary.missing)),
    ];
    return DetailSectionCard(
      title: messages.mealReviewFindings,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final finding in findings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(finding)),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                messages.mealReviewContext,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
