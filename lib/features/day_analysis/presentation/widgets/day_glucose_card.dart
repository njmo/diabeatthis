import 'package:flutter/material.dart';

import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/timeline_analysis_charts.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_glucose_ranges.dart';
import 'day_metric_grid.dart';
import 'day_summary_card.dart';

class DayGlucoseCard extends StatelessWidget {
  final String title;
  final GlucosePeriodSummary? summary;
  final String? information;
  const DayGlucoseCard({
    super.key,
    required this.title,
    required this.summary,
    this.information,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final s = summary;
    final inRangePercent = s?.window.percent(s.window.inRange);
    return DaySummaryCard(
      title: title,
      information: [
        if (information != null) information!,
        lang.dayGlucoseMethod,
        lang.dayGlucoseBarBasis,
      ].join('\n\n'),
      warnings: [
        if (s == null)
          lang.daySourceUnavailable
        else if (s.window.observed == Duration.zero)
          lang.dayNoGlucoseObservation
        else if (s.window.missing > Duration.zero && !s.hasContinuousReadings)
          lang.dayWarningMissingDuration(formatDurationLabel(s.window.missing)),
      ],
      children: [
        if (s == null)
          Text(lang.daySourceUnavailable)
        else ...[
          DayMetricGrid(
            children: [
              AnalysisMetric(
                label: lang.dayGlucoseMean,
                value: format.number(s.mean, decimals: 0, unit: ' mg/dl'),
                icon: Icons.monitor_heart_outlined,
              ),
              AnalysisMetric(
                label: lang.dayGlucoseExtremes,
                value: s.window.readings.isEmpty
                    ? '—'
                    : '${s.window.minimum!.sgv}–${s.window.peak!.sgv} mg/dl',
                icon: Icons.swap_vert,
              ),
              AnalysisMetric(
                label: lang.mealTimeInRangeLabel,
                value: format.percent(inRangePercent),
                icon: Icons.track_changes,
              ),
              AnalysisMetric(
                label: lang.dayCoverage,
                value: format.percent(s.coveragePercent),
                icon: Icons.sensors,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (s.window.readings.isNotEmpty) ...[
            TimelineGlucoseChart(
              chartStart: s.window.start,
              chartEnd: s.window.end,
              glucoseReadings: s.window.readings,
            ),
            const SizedBox(height: 16),
          ],
          if (s.window.observed == Duration.zero)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(lang.dayNoGlucoseObservation),
            ),
          DayGlucoseRanges(summary: s.window),
        ],
      ],
    );
  }
}
