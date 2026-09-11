import 'package:flutter/material.dart';

import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import 'day_glucose_ranges.dart';
import 'day_summary_card.dart';

class DayGlucoseCard extends StatelessWidget {
  final String title;
  final GlucosePeriodSummary? summary;
  const DayGlucoseCard({super.key, required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final s = summary;
    return DaySummaryCard(
      title: title,
      warnings: [
        if (s == null)
          lang.daySourceUnavailable
        else if (s.window.observed == Duration.zero)
          lang.dayNoGlucoseObservation
        else if (s.window.missing > Duration.zero)
          lang.dayWarningMissingDuration(formatDurationLabel(s.window.missing)),
      ],
      children: [
        if (s == null)
          Text(lang.daySourceUnavailable)
        else ...[
          ResponsiveMetricList(
            maxColumns: 2,
            children: [
              AnalysisMetric(
                label: lang.dayGlucoseMean,
                value: s.mean == null
                    ? '—'
                    : '${s.mean!.toStringAsFixed(0)} mg/dl',
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
                label: lang.dayCoverage,
                value: s.coveragePercent == null
                    ? '—'
                    : '${s.coveragePercent!.toStringAsFixed(0)}%',
                icon: Icons.sensors,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (s.window.observed == Duration.zero)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(lang.dayNoGlucoseObservation),
            ),
          DayGlucoseRanges(summary: s.window),
          const SizedBox(height: 8),
          Text(
            lang.dayGlucoseMethod,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
