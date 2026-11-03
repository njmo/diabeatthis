import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../common/models/status_timeline.dart';
import 'dashboard_activity_progress.dart';

class DashboardActivityDetails extends StatelessWidget {
  const DashboardActivityDetails({
    super.key,
    required this.activity,
    required this.now,
  });
  final ActivityLogSummaryData activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final timeline = StatusTimeline(start: activity.startedAt, now: now);
    final duration = activity.durationMinutes;
    final lang = context.lang;
    final timing = timeline.planned
        ? '${lang.dashboardActivityStartsIn(timeline.minutesUntilStart)}${duration == null ? '' : ' · ${lang.dashboardActivityDuration(duration)}'}'
        : duration != null && duration > 0
        ? lang.dashboardActivityProgress(timeline.elapsedMinutes, duration)
        : lang.dashboardActivityElapsed(timeline.elapsedMinutes);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeline.planned
                    ? lang.dashboardPlannedActivityTitle
                    : lang.dashboardActivityInProgressCardTitle,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            Text(timing, style: theme.textTheme.bodyMedium),
          ],
        ),
        if (!timeline.planned && duration != null && duration > 0) ...[
          const SizedBox(height: 8),
          DashboardActivityProgress(activity: activity, now: now),
        ],
      ],
    );
  }
}
