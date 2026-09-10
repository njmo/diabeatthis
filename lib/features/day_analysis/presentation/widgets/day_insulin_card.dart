import 'package:flutter/material.dart';

import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../common/l10n/language.dart';
import 'day_basal_rows.dart';
import 'day_stat_row.dart';
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
    String units(double? value) =>
        value == null ? '—' : '${value.toStringAsFixed(2)} U';
    return DaySummaryCard(
      title: lang.dayInsulinTitle,
      children: [
        if (summary == null) Text(lang.daySourceUnavailable),
        DayStatRow(
          label: lang.dayRecordedBoluses,
          value: units(summary?.units),
        ),
        DayStatRow(
          label: lang.dayManualBoluses,
          value: units(
            summary == null
                ? null
                : summary!.manualUnits + summary!.wizardUnits,
          ),
        ),
        DayStatRow(
          label: lang.dayCorrectionBoluses,
          value: units(summary?.otherUnits),
        ),
        DayStatRow(label: lang.dayNightBoluses, value: units(night?.units)),
        DayBasalRows(summary: basal, boluses: summary),
        DayBasalRows(summary: nightBasal, boluses: night, isNight: true),
        Text(lang.dayInsulinLimit),
      ],
    );
  }
}
