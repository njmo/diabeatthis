import 'package:flutter/material.dart';

import '../../history/insulin_basal_summary.dart';
import '../../history/insulin_bolus_summary.dart';
import '../../l10n/language.dart';
import '../../widgets/analysis_metric.dart';
import 'day_insulin_summary.dart';
import 'day_metric_grid.dart';
import 'day_stat_formatter.dart';

class DayBasalRows extends StatelessWidget {
  final InsulinBasalSummary? summary;
  final InsulinBolusSummary? boluses;
  final bool isNight;

  const DayBasalRows({
    super.key,
    required this.summary,
    required this.boluses,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final format = DayStatFormatter(lang.localeName);
    final data = summary;
    final covered = data != null && data.coveredDuration > Duration.zero;
    final units = format.insulin;
    final insulin = DayInsulinSummary(boluses: boluses, basal: summary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          isNight ? lang.dayNightBasalTitle : lang.dayBasalTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        DayMetricGrid(
          children: [
            AnalysisMetric(
              label: lang.dayBasalCoverage,
              value: data == null
                  ? '—'
                  : format.percent(data.coverage * 100, decimals: 1),
            ),
            AnalysisMetric(
              label: lang.dayBasalTitle,
              value: units(covered ? data.units : null),
            ),
            AnalysisMetric(
              label: lang.dayProfileBasal,
              value: units(covered ? data.profileUnits : null),
            ),
            AnalysisMetric(
              label: lang.dayAddedBasal,
              value: units(covered ? data.addedUnits : null),
            ),
            AnalysisMetric(
              label: lang.dayReducedBasal,
              value: units(covered ? data.reducedUnits : null),
            ),
            AnalysisMetric(
              label: insulin.isPartial
                  ? lang.dayInsulinPartialSum
                  : lang.dayInsulinSum,
              value: units(insulin.totalUnits),
            ),
          ],
        ),
      ],
    );
  }
}
