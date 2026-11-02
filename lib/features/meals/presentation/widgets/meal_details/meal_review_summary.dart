import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/information_button.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../../../common/widgets/section_surface.dart';
import 'meal_detail_formatters.dart';
import 'meal_glucose_milestones.dart';
import 'meal_time_in_range_highlight.dart';

/// Describes observed results without attributing them to food or insulin alone.
class MealReviewSummary extends StatelessWidget {
  const MealReviewSummary({super.key, required this.summary});
  final GlucoseWindowSummary summary;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final peak = summary.peak;
    final baseline = summary.baseline;
    final endpoint = summary.endpoint;
    final hasData = summary.observed > Duration.zero;
    final coverage = summary.sampleCoverage;
    final hasHistoryGap = hasData && coverage.hasSignificantMissing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealTimeInRangeHighlight(summary: summary),
        const SizedBox(height: 12),
        SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang.mealReviewGlucose,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  InformationButton(
                    title: lang.mealReadableSummaryTitle,
                    message:
                        '${lang.mealReadableContext}\n\n${lang.mealFirstPeakMethod}\n\n${lang.mealResponseRiseMethod}',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasHistoryGap) ...[
                Text(
                  lang.mealMissingSampleSummary(
                    coverage.missing,
                    coverage.expected,
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
              ],
              if (!hasData)
                Text(lang.mealNoAnalysisData)
              else ...[
                ResponsiveMetricList(
                  maxColumns: 2,
                  minimumWidth: 80,
                  children: [
                    AnalysisMetric(
                      label: lang.mealReviewBaseline,
                      value: baseline == null ? '—' : '${baseline.sgv}',
                      detail: baseline == null
                          ? lang.mealReviewNoNearbyReading
                          : '${mealTime(baseline.date)} · mg/dl',
                      labelLines: 2,
                    ),
                    AnalysisMetric(
                      label: lang.mealPeakAfterStart,
                      value: peak == null ? '—' : '${peak.sgv}',
                      detail: peak == null
                          ? lang.mealNoAnalysisData
                          : '${formatDurationOffset(peak.date.difference(summary.start))} · mg/dl',
                      labelLines: 2,
                    ),
                    if (summary.minimum != null)
                      AnalysisMetric(
                        label: lang.mealReviewMinimum,
                        value: '${summary.minimum!.sgv}',
                        detail: '${mealTime(summary.minimum!.date)} · mg/dl',
                        labelLines: 2,
                      ),
                    AnalysisMetric(
                      label: lang.mealReviewLast,
                      value: endpoint == null ? '—' : '${endpoint.sgv}',
                      detail: endpoint == null
                          ? lang.mealResponseMissingEndpoints
                          : '${mealTime(endpoint.date)} · mg/dl',
                      labelLines: 2,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        MealGlucoseMilestones(summary: summary),
      ],
    );
  }
}
