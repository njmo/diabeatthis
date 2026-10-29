import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/drift/database_impl.dart';

class ActivityOccurrenceCard extends StatelessWidget {
  const ActivityOccurrenceCard({
    super.key,
    required this.row,
    required this.name,
    required this.onConfirm,
    required this.onSkip,
    required this.onMove,
    required this.onHistory,
    this.onDelete,
  });
  final ActivityOccurrenceData row;
  final String name;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;
  final VoidCallback onMove;
  final VoidCallback onHistory;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final future = row.startedAt > clock.now().millisecondsSinceEpoch;
    final status = switch (row.status) {
      'planned' => context.lang.activitySchedulePlanned,
      'skipped' => context.lang.activityScheduleSkipped,
      'missed' => context.lang.activityScheduleMissed,
      'recorded' => context.lang.activityScheduleRecorded,
      _ => context.lang.activitySchedulePending,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: context.lang.activityOccurrenceDelete,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            Text(
              '${DateFormat.yMd(context.lang.localeName).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(row.startedAt))} · ${row.durationMinutes == null ? context.lang.activityManualEnd : '${row.durationMinutes} ${context.lang.activityMinutesUnit}'}',
            ),
            Text(
              row.scheduleId == null
                  ? context.lang.activitySingleOccurrence
                  : context.lang.activityRecurringOccurrence,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(status),
            if (future && row.status != 'skipped')
              Wrap(
                spacing: 8,
                children: [
                  if (row.status == 'pending')
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(context.lang.activityScheduleYes),
                    ),
                  TextButton(
                    onPressed: onMove,
                    child: Text(context.lang.activityScheduleMove),
                  ),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(context.lang.activityScheduleNo),
                  ),
                ],
              ),
            if (!future && row.status == 'missed')
              TextButton(
                onPressed: onHistory,
                child: Text(context.lang.activityHistorySave),
              ),
          ],
        ),
      ),
    );
  }
}
