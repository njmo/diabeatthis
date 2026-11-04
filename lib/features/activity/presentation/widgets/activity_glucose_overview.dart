import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/detail_metric_section.dart';
import '../../../../common/widgets/detail_metric_tile.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_log_details_data.dart';
import '../../data/models/activity_session_summary.dart';
import '../utils/activity_log_formatters.dart';
import 'activity_reading_coverage.dart';
import 'activity_session_chart.dart';

class ActivityGlucoseOverview extends StatelessWidget {
  final ActivityLogAnalysisData analysis;
  final ActivityLogDetailsData log;
  const ActivityGlucoseOverview({
    super.key,
    required this.analysis,
    required this.log,
  });
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final summary = ActivitySessionSummary(analysis);
    final period = summary.period;
    final delta = summary.displayDelta;
    final displayedEnd = summary.displayEnd;
    final afterEnd = summary.displayEndIsAfter;
    final endExplanation = afterEnd
        ? lang.activityPostEndReadingExplanation(
            formatActivityLogTime(analysis.activityEnd),
            formatActivityLogTime(displayedEnd!.date),
            formatDurationLabel(
              displayedEnd.date.difference(analysis.activityEnd),
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityReadingCoverage(summary: summary),
        const SizedBox(height: 16),
        DetailMetricSection(
          title: lang.activityGlucoseSummaryTitle,
          icon: Icons.insights_rounded,
          metrics: [
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.play_arrow_rounded,
              label: lang.activityStartGlucoseLabel,
              value: summary.start?.sgv.toString() ?? '—',
              unit: 'mg/dl',
              detail: summary.start == null
                  ? lang.activityMissingData
                  : lang.activityReadingTime(
                      formatActivityLogTime(summary.start!.date),
                    ),
            ),
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.stop_rounded,
              label: lang.activityEndGlucose,
              value: displayedEnd?.sgv.toString() ?? '—',
              explanation: endExplanation,
              unit: 'mg/dl',
              detail: displayedEnd != null
                  ? (afterEnd
                        ? lang.activityPostEndReadingTime(
                            formatActivityLogTime(displayedEnd.date),
                          )
                        : lang.activityReadingTime(
                            formatActivityLogTime(displayedEnd.date),
                          ))
                  : summary.lastDuring == null
                  ? lang.activityMissingData
                  : lang.activityEndReadingUnavailable(
                      summary.lastDuring!.sgv.toString(),
                      formatActivityLogTime(summary.lastDuring!.date),
                    ),
            ),
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.compare_arrows_rounded,
              label: afterEnd
                  ? lang.activityDeltaToPostReading
                  : lang.activityGlucoseDelta,
              explanation: endExplanation,
              value: delta == null ? '—' : '${delta > 0 ? '+' : ''}$delta',
              unit: 'mg/dl',
            ),
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.swap_vert_rounded,
              label: lang.activityRangeLabel,
              value: period.window.minimum == null
                  ? '—'
                  : '${period.window.minimum!.sgv}–${period.window.peak!.sgv}',
              unit: 'mg/dl',
            ),
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.show_chart_rounded,
              label: lang.activityAverageGlucoseLabel,
              value: period.mean?.round().toString() ?? '—',
              unit: 'mg/dl',
            ),
            DetailMetricTile(
              minimumLabelLines: 2,
              icon: Icons.bakery_dining_rounded,
              label: lang.activityRecordedTreats,
              value: analysis.treatCarbsDuringActivity.toString(),
              unit: 'g',
              detail: lang.activityRecordedTreatCount(
                analysis.treatsDuringActivity.length.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ActivitySessionChart(
          title: lang.activityTrainingChart,
          start: analysis.activityStart,
          end: summary.overviewChartEnd,
          readings: summary.overviewReadings,
          activityEnd: afterEnd ? analysis.activityEnd : null,
        ),
      ],
    );
  }
}
