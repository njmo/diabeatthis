import 'package:flutter/material.dart';

import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_session_summary.dart';
import '../utils/activity_log_formatters.dart';
import 'activity_after_meals_card.dart';
import 'activity_corrections_card.dart';
import 'activity_observation_info_card.dart';
import 'activity_session_chart.dart';
import 'activity_session_events.dart';

class ActivityAfterSection extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  const ActivityAfterSection({super.key, required this.analysis});
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final summary = ActivitySessionSummary(analysis);
    final period = GlucosePeriodSummary.calculate(
      analysis.glucoseReadings,
      analysis.activityEnd,
      analysis.chartEnd,
    );
    final rise = summary.firstRise;
    final low = summary.after.where((g) => g.sgv < 70).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityObservationInfoCard(analysis: analysis),
        const SizedBox(height: 16),
        ActivityAfterMealsCard(analysis: analysis),
        const SizedBox(height: 16),
        DetailMetricSection(
          title: lang.activityTabAfter,
          icon: Icons.sports_score_rounded,
          metrics: [
            DetailMetricTile(
              icon: Icons.show_chart_rounded,
              label: lang.activityAfterAverage,
              value: period.mean?.round().toString() ?? '—',
              unit: 'mg/dl',
            ),
            DetailMetricTile(
              icon: Icons.swap_vert_rounded,
              label: lang.activityRangeLabel,
              value: period.window.minimum == null
                  ? '—'
                  : '${period.window.minimum!.sgv}–${period.window.peak!.sgv}',
              unit: 'mg/dl',
            ),
          ],
        ),
        const SizedBox(height: 16),
        ActivitySessionChart(
          title: lang.activityTabAfter,
          start: analysis.activityEnd,
          end: analysis.chartEnd,
          readings: summary.after,
        ),
        const SizedBox(height: 16),
        SummaryDetailCard(
          title: lang.activityFirstRise,
          icon: Icons.trending_up_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rise.startedAt == null
                    ? (rise.hasObservation
                          ? lang.activityNoRise
                          : lang.activityMissingData)
                    : '${formatActivityLogTime(rise.startedAt)} · ${lang.activityRiseAfter(rise.startedAt!.difference(analysis.activityEnd).inMinutes.toString())}',
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(lang.mealResponseMethodTitle),
                children: [Text(lang.activityRiseMethod)],
              ),
              const SizedBox(height: 8),
              Text(
                '${lang.activityFirstLow}: ${low == null ? lang.activityNoLowRecorded : '${low.sgv} mg/dl · ${formatActivityLogTime(low.date)}'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ActivityCorrectionsCard(analysis: analysis, afterActivity: true),
        const SizedBox(height: 16),
        ActivitySessionEvents(
          title: lang.activityAfterEvents,
          treatments: analysis.chartTreatments,
          start: analysis.activityEnd,
          end: analysis.chartEnd,
          includeStart: false,
        ),
      ],
    );
  }
}
