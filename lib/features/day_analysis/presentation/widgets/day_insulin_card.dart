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
  final InsulinBasalSummary? basal;
  final bool isNight;
  const DayInsulinCard({
    super.key,
    required this.summary,
    this.basal,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final units = format.insulin;
    final basalTitle = isNight ? lang.dayNightBasalTitle : lang.dayBasalTitle;
    final covered = basal != null && basal!.coveredDuration > Duration.zero;
    return DaySummaryCard(
      title: isNight ? lang.dayNightInsulinTitle : lang.dayInsulinTitle,
      information: lang.dayInsulinLimit,
      warnings: [
        if (summary == null)
          '${lang.dayRecordedBoluses}: ${lang.daySourceUnavailable}',
        if (basal == null)
          '$basalTitle: ${lang.daySourceUnavailable}'
        else if (basal!.coveredDuration < basal!.duration)
          '$basalTitle: ${lang.dayWarningMissingDuration(formatDurationLabel(basal!.duration - basal!.coveredDuration))}',
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
              label: isNight ? lang.dayNightBoluses : lang.dayRecordedBoluses,
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
            DayBasalRows(summary: basal, boluses: summary, isNight: isNight),
          ],
        ),
      ],
    );
  }
}
