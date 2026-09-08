import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_highlight_panel.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../data/models/meal_analysis_data.dart';
import 'meal_detail_formatters.dart';
import 'meal_excursion_summary.dart';
import 'meal_outcome_details.dart';
import 'meal_range_summary.dart';
import 'meal_response_summary.dart';

class MealOutcomeSection extends StatelessWidget {
  final MealAnalysisData analysis;
  final bool advanced;

  const MealOutcomeSection({
    super.key,
    required this.analysis,
    this.advanced = false,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalysisHighlightPanel(
          title: messages.mealReviewTitle,
          subtitle:
              '${mealTime(analysis.mealTime)}–${mealTime(analysis.chartEnd)} · '
              '${formatDurationLabel(analysis.chartEnd.difference(analysis.mealTime))} · mg/dl',
          child: ResponsiveMetricList(
            minimumWidth: 80,
            children: [
              AnalysisMetric(
                labelLines: 2,
                label: messages.mealReviewBaseline,
                value: summary.baseline?.sgv.toString() ?? '—',
                detail: summary.baseline == null
                    ? null
                    : mealTime(summary.baseline!.date),
              ),
              AnalysisMetric(
                labelLines: 2,
                label: messages.mealReviewPeak,
                value: peak?.sgv.toString() ?? '—',
                detail: peak == null
                    ? null
                    : '${mealTime(peak.date)} · '
                          '${formatDurationOffset(peak.date.difference(analysis.mealTime))}',
              ),
              AnalysisMetric(
                labelLines: 2,
                label: messages.mealReviewLast,
                value: summary.last?.sgv.toString() ?? '—',
                detail: summary.last == null
                    ? null
                    : mealTime(summary.last!.date),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MealResponseSummary(
                  summary: summary,
                  complete: analysis.hasFullGlucoseWindow,
                ),
                const SizedBox(height: 20),
                MealRangeSummary(summary: summary),
                MealExcursionSummary(summary: summary),
                const SizedBox(height: 8),
                if (advanced) MealOutcomeDetails(summary: summary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
