import 'package:flutter/material.dart';

import '../../../../../common/history/glucose_window_summary.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/utils/format_duration_label.dart';
import '../../../../../common/widgets/analysis_metric.dart';
import '../../../../../common/widgets/responsive_metric_list.dart';
import '../../../../../common/widgets/section_surface.dart';
import '../../../common/formatters/format_meal_rise_timing.dart';
import '../../controllers/meal_glucose_milestones_controller.dart';
import 'meal_detail_formatters.dart';

class MealGlucoseMilestones extends StatelessWidget {
  const MealGlucoseMilestones({super.key, required this.summary});
  final GlucoseWindowSummary summary;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final milestones = const MealGlucoseMilestonesController().build(summary);
    final first = milestones.first;
    final rise = milestones.rise;
    final peak = summary.peak;
    final delta = summary.endDelta;
    final metrics = <Widget>[
      if (peak != null)
        AnalysisMetric(
          icon: Icons.schedule,
          label: lang.mealTimeToHighest,
          value: formatDurationLabel(peak.date.difference(summary.start)),
          detail: '${peak.sgv} mg/dl · ${mealTime(peak.date)}',
          labelLines: 2,
        ),
      if (rise.startedAt != null)
        AnalysisMetric(
          icon: Icons.trending_up,
          label: lang.mealResponseRiseTime,
          value: formatMealRiseTiming(rise, summary.start, lang),
          detail:
              '${mealTime(rise.startedAt!)}–${mealTime(rise.onsetIntervalEnd!)}',
          labelLines: 2,
        ),
      if (delta != null)
        AnalysisMetric(
          icon: Icons.compare_arrows,
          label: lang.mealResponseDelta,
          value: '${delta > 0 ? '+' : ''}$delta mg/dl',
          detail: '${summary.baseline!.sgv} → ${summary.endpoint!.sgv}',
          labelLines: 2,
        ),
      if (first.peak != null)
        AnalysisMetric(
          icon: Icons.show_chart,
          label: lang.mealFirstPeak,
          value: mealTime(first.peak!.date),
          detail:
              '${first.peak!.sgv} mg/dl · ${formatDurationOffset(first.peak!.date.difference(summary.start))}',
          labelLines: 2,
        ),
      if (first.firstInRangeAfter != null)
        AnalysisMetric(
          icon: Icons.check_circle_outline,
          label: lang.mealFirstRangeAfterFirstPeak,
          value: mealTime(first.firstInRangeAfter!.date),
          detail:
              '${first.firstInRangeAfter!.sgv} mg/dl · ${formatDurationOffset(first.firstInRangeAfter!.date.difference(summary.start))}',
          labelLines: 3,
        ),
    ];
    if (metrics.isEmpty) return const SizedBox.shrink();
    return SectionSurface(
      child: ResponsiveMetricList(
        maxColumns: 2,
        minimumWidth: 120,
        children: metrics,
      ),
    );
  }
}
