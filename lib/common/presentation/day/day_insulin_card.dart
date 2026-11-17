import 'package:flutter/material.dart';

import '../../history/insulin_basal_summary.dart';
import '../../history/insulin_bolus_summary.dart';
import '../../l10n/language.dart';
import '../../widgets/analysis_metric.dart';
import 'day_basal_rows.dart';
import 'day_insulin_breakdown.dart';
import 'day_insulin_summary.dart';
import 'day_metric_grid.dart';
import 'day_stat_formatter.dart';
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
    final insulin = DayInsulinSummary(boluses: summary, basal: basal);
    final warnings = insulin.warnings(lang, isNight: isNight);
    return DaySummaryCard(
      title: isNight ? lang.dayNightInsulinTitle : lang.dayInsulinTitle,
      information: lang.dayInsulinLimit,
      children: [
        DayMetricGrid(
          equalRowHeights: true,
          children: [
            AnalysisMetric(
              label: insulin.isPartial
                  ? lang.dayInsulinCompactPartialTotal
                  : lang.dayInsulinCompactTotal,
              value: units(insulin.totalUnits),
            ),
            AnalysisMetric(
              label: lang.dayRecordedBoluses,
              value: units(summary?.units),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DayInsulinBreakdown(
          basal: insulin.basalUnits,
          boluses: summary?.units,
          smb: summary?.otherUnits,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(lang.dayReviewDetails),
          children: [
            if (warnings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    warnings.join('\n'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            DayBasalRows(summary: basal, boluses: summary, isNight: isNight),
          ],
        ),
      ],
    );
  }
}
