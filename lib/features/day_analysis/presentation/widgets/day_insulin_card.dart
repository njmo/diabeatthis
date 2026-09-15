import 'package:flutter/material.dart';

import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/utils/format_duration_label.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_basal_rows.dart';
import 'day_insulin_breakdown.dart';
import 'day_metric_grid.dart';
import 'day_summary_card.dart';

class DayInsulinCard extends StatelessWidget {
  final InsulinBolusSummary? summary;
  final InsulinBolusSummary? night;
  final InsulinBasalSummary? basal;
  final InsulinBasalSummary? nightBasal;
  const DayInsulinCard({
    super.key,
    required this.summary,
    required this.night,
    this.basal,
    this.nightBasal,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final units = format.insulin;
    final covered = basal != null && basal!.coveredDuration > Duration.zero;
    return DaySummaryCard(
      title: lang.dayInsulinTitle,
      information: lang.dayInsulinLimit,
      warnings: [
        if (summary == null || night == null)
          '${lang.dayRecordedBoluses}: ${lang.daySourceUnavailable}',
        for (final entry in [
          (lang.dayBasalTitle, basal),
          (lang.dayNightBasalTitle, nightBasal),
        ])
          if (entry.$2 == null)
            '${entry.$1}: ${lang.daySourceUnavailable}'
          else if (entry.$2!.coveredDuration < entry.$2!.duration)
            '${entry.$1}: ${lang.dayWarningMissingDuration(formatDurationLabel(entry.$2!.duration - entry.$2!.coveredDuration))}',
      ],
      children: [
        DayMetricGrid(
          children: [
            AnalysisMetric(
              label: basal?.coverage == 1
                  ? lang.dayInsulinSum
                  : lang.dayInsulinPartialSum,
              value: units(
                covered && summary != null
                    ? basal!.units + summary!.units
                    : null,
              ),
              icon: Icons.water_drop_outlined,
            ),
            AnalysisMetric(
              label: lang.dayRecordedBoluses,
              value: units(summary?.units),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DayInsulinBreakdown(
          basal: covered ? basal!.units : null,
          boluses: summary?.units,
          smb: summary?.otherUnits,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(lang.dayReviewDetails),
          children: [
            AnalysisMetric(
              label: lang.dayNightBoluses,
              value: units(night?.units),
            ),
            DayBasalRows(summary: basal, boluses: summary),
            DayBasalRows(summary: nightBasal, boluses: night, isNight: true),
          ],
        ),
      ],
    );
  }
}
