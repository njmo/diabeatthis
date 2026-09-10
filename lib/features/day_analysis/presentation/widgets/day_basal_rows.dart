import 'package:flutter/material.dart';

import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/l10n/language.dart';
import 'day_stat_row.dart';

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
    final data = summary;
    final covered = data != null && data.coveredDuration > Duration.zero;
    String units(double? value) =>
        value == null ? '—' : '${value.toStringAsFixed(2)} U';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(
          isNight ? lang.dayNightBasalTitle : lang.dayBasalTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        DayStatRow(
          label: lang.dayBasalCoverage,
          value: data == null
              ? '—'
              : '${(data.coverage * 100).toStringAsFixed(1)}%',
        ),
        DayStatRow(
          label: lang.dayBasalTitle,
          value: units(covered ? data.units : null),
        ),
        DayStatRow(
          label: lang.dayProfileBasal,
          value: units(covered ? data.profileUnits : null),
        ),
        DayStatRow(
          label: lang.dayAddedBasal,
          value: units(covered ? data.addedUnits : null),
        ),
        DayStatRow(
          label: lang.dayReducedBasal,
          value: units(covered ? data.reducedUnits : null),
        ),
        DayStatRow(
          label: data != null && data.coverage == 1
              ? lang.dayInsulinSum
              : lang.dayInsulinPartialSum,
          value: units(
            covered && boluses != null ? data.units + boluses!.units : null,
          ),
        ),
      ],
    );
  }
}
