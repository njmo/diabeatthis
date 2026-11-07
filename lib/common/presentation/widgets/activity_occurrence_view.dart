import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';

class ActivityOccurrenceView extends StatelessWidget {
  const ActivityOccurrenceView({
    super.key,
    required this.startedAt,
    required this.durationMinutes,
    required this.status,
    required this.recurring,
    this.statusLabel,
    required this.name,
    this.onConfirm,
    this.onSkip,
    this.onMove,
    this.onHistory,
    this.onDelete,
    this.onRetry,
  });
  final int startedAt;
  final int? durationMinutes;
  final String status;
  final bool recurring;
  final String? statusLabel;
  final String name;
  final VoidCallback? onConfirm;
  final VoidCallback? onSkip;
  final VoidCallback? onMove;
  final VoidCallback? onHistory;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final future = startedAt > clock.now().millisecondsSinceEpoch;
    final label =
        statusLabel ??
        switch (status) {
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
              '${DateFormat.yMd(context.lang.localeName).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(startedAt))} · ${durationMinutes == null ? context.lang.activityManualEnd : '$durationMinutes ${context.lang.activityMinutesUnit}'}',
            ),
            Text(
              !recurring
                  ? context.lang.activitySingleOccurrence
                  : context.lang.activityRecurringOccurrence,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(label),
            if (onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.lang.familyPlanRetry),
              ),
            if (future && status != 'skipped')
              Wrap(
                spacing: 8,
                children: [
                  if (status == 'pending' && onConfirm != null)
                    TextButton(
                      onPressed: onConfirm,
                      child: Text(context.lang.activityScheduleYes),
                    ),
                  if (onMove != null)
                    TextButton(
                      onPressed: onMove,
                      child: Text(context.lang.activityScheduleMove),
                    ),
                  if (onSkip != null)
                    TextButton(
                      onPressed: onSkip,
                      child: Text(context.lang.activityScheduleNo),
                    ),
                ],
              ),
            if (!future && status == 'missed' && onHistory != null)
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
