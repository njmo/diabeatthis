import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../common/models/status_timeline.dart';
import '../../common/widgets/status_time_progress.dart';

class DashboardActivityProgress extends StatelessWidget {
  const DashboardActivityProgress({
    super.key,
    required this.activity,
    required this.now,
  });

  final ActivityLogSummaryData activity;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final duration = activity.durationMinutes;
    if (duration == null || duration <= 0 || activity.startedAt.isAfter(now)) {
      return const SizedBox.shrink();
    }
    final end = activity.startedAt.add(Duration(minutes: duration));
    final remaining = StatusTimeline(
      start: activity.startedAt,
      end: end,
      now: now,
    ).remainingMinutes!;
    return StatusTimeProgress(
      startedAt: activity.startedAt,
      endsAt: end,
      now: now,
      label: remaining <= 0
          ? context.lang.dashboardActivityTimePassed
          : context.lang.dashboardActivityEndsIn(remaining),
    );
  }
}
