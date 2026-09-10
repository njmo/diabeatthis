import 'package:flutter/material.dart';
import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/l10n/language.dart';
import 'day_stat_row.dart';
import 'day_summary_card.dart';

class DayGlucoseCard extends StatelessWidget {
  final String title;
  final GlucosePeriodSummary? summary;
  const DayGlucoseCard({super.key, required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final s = summary;
    String percent(double? n) => n == null ? '—' : '${n.toStringAsFixed(0)}%';
    return DaySummaryCard(
      title: title,
      children: [
        if (s == null)
          Text(lang.daySourceUnavailable)
        else ...[
          DayStatRow(
            label: lang.dayGlucoseMean,
            value: s.mean == null ? '—' : '${s.mean!.toStringAsFixed(0)} mg/dl',
          ),
          DayStatRow(
            label: lang.dayGlucoseExtremes,
            value: s.window.readings.isEmpty
                ? '—'
                : '${s.window.minimum!.sgv}–${s.window.peak!.sgv} mg/dl',
          ),
          DayStatRow(
            label: lang.dayInRange,
            value: percent(s.window.percent(s.window.inRange)),
          ),
          DayStatRow(
            label: lang.dayBelowRange,
            value: percent(s.window.percent(s.window.belowRange)),
          ),
          DayStatRow(
            label: lang.dayAboveRange,
            value: percent(s.window.percent(s.window.aboveRange)),
          ),
          DayStatRow(
            label: lang.dayCoverage,
            value: percent(s.coveragePercent),
          ),
          Text(
            lang.dayGlucoseMethod,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
