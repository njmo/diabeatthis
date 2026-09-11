import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/detail_section_card.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../common/widgets/meal_stat_tile.dart';
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
      baselinePolicy: GlucoseBaselinePolicy.nearest,
      readings: analysis.glucoseReadings,
      start: analysis.mealTime,
      end: analysis.chartEnd,
    );
    final peak = summary.peak;
    final returned = summary.firstReturnAfterPeak;
    final planned = details.plannedSnapshot;
    final consumed = details.consumedSnapshot;
    final findings = <Widget>[
      if (peak != null)
        MealStatTile(
          icon: Icons.trending_up_rounded,
          label: messages.mealReviewPeak,
          value: formatMgdl(peak.sgv),
          detail: formatDurationOffset(peak.date.difference(analysis.mealTime)),
        ),
      if (returned != null)
        MealStatTile(
          icon: Icons.check_circle_outline_rounded,
          label: messages.mealReviewReturn,
          value: mealTime(returned.date),
        ),
      if (planned != null &&
          consumed != null &&
          planned.totalCarbsG != consumed.totalCarbsG)
        MealStatTile(
          icon: Icons.restaurant_rounded,
          label: messages.mealPortionDifference,
          value: formatSignedGrams(consumed.totalCarbsG - planned.totalCarbsG),
        ),
      if (analysis.linkedMeals.isNotEmpty)
        MealStatTile(
          icon: Icons.restaurant_menu_rounded,
          label: messages.mealOtherEventsCount,
          value: '${analysis.linkedMeals.length}',
          detail: messages.mealReviewOtherMeals,
        ),
      if (analysis.linkedActivities.isNotEmpty)
        MealStatTile(
          icon: Icons.directions_run_rounded,
          label: messages.mealActivitiesCount,
          value: '${analysis.linkedActivities.length}',
          detail: messages.mealReviewActivity,
        ),
      if (summary.missing > Duration.zero)
        MealStatTile(
          icon: Icons.signal_cellular_connected_no_internet_0_bar,
          label: messages.mealReviewMissing,
          value: formatDurationLabel(summary.missing),
        ),
    ];
    return DetailSectionCard(
      title: messages.mealReviewFindings,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveMetricList(maxColumns: 2, children: findings),
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
