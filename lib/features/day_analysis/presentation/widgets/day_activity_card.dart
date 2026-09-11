import 'package:flutter/material.dart';
import '../../../../common/l10n/language.dart';
import '../../domain/models/day_activity_summary.dart';
import 'day_stat_row.dart';
import 'day_summary_card.dart';

class DayActivityCard extends StatelessWidget {
  final List<DayActivitySummary>? activities;
  const DayActivityCard({super.key, required this.activities});

  @override
  Widget build(BuildContext context) => DaySummaryCard(
    title: context.lang.dayActivityTitle,
    warnings: [if (activities == null) context.lang.daySourceUnavailable],
    children: [
      if (activities == null)
        Text(context.lang.daySourceUnavailable)
      else if (activities!.isEmpty)
        Text(context.lang.dayNoActivities)
      else
        for (final activity in activities!)
          DayStatRow(
            label: activity.name,
            value:
                '${activity.observedDuration.inMinutes} min${activity.ongoing ? ' • ${context.lang.dayOngoing}' : ''}',
          ),
    ],
  );
}
