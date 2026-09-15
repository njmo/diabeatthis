import 'package:flutter/material.dart';

import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/analysis_metric.dart';
import '../formatters/day_stat_formatter.dart';
import 'day_metric_grid.dart';

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
              label: data != null && data.coverage == 1
                  ? lang.dayInsulinSum
                  : lang.dayInsulinPartialSum,
              value: units(
                covered && boluses != null ? data.units + boluses!.units : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
