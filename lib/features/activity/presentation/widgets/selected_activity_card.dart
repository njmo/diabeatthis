import 'package:flutter/material.dart';
import '../../../../common/l10n/language.dart';
import '../../data/drafts/activity_draft.dart';

class SelectedActivityCard extends StatelessWidget {
  const SelectedActivityCard({
    super.key,
    required this.activity,
    required this.onChange,
  });

  final ActivityDraft activity;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _activityName(activity);
    final duration = _activityDurationMinutes(activity);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.directions_run,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(context, duration),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onChange != null)
              IconButton(
                tooltip: context.lang.dashboardChangeActivityTooltip,
                onPressed: onChange,
                icon: const Icon(Icons.edit),
              ),
          ],
        ),
      ),
    );
  }

  static String _activityName(ActivityDraft activity) {
    return activity.map(
      existing: (activity) => activity.name,
      draft: (activity) => activity.name,
    );
  }

  static int? _activityDurationMinutes(ActivityDraft activity) {
    return activity.map(
      existing: (activity) => activity.durationMinutes,
      draft: (activity) => activity.durationMinutes,
    );
  }

  static String _formatDuration(BuildContext context, int? minutes) {
    if (minutes == null) {
      return context.lang.activityManualEnd;
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return context.lang.dashboardPlannedDurationPrefix(
        context.lang.durationMinutesShort(minutes),
      );
    }
    if (remainingMinutes == 0) {
      return context.lang.dashboardPlannedDurationPrefix(
        context.lang.durationHoursShort(hours),
      );
    }
    return context.lang.dashboardPlannedDurationPrefix(
      '${context.lang.durationHoursShort(hours)} ${context.lang.durationMinutesShort(remainingMinutes)}',
    );
  }
}
