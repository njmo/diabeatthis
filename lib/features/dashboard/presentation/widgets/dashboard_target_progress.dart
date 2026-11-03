import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../common/models/status_timeline.dart';
import '../../common/widgets/status_time_progress.dart';

class DashboardTargetProgress extends StatelessWidget {
  const DashboardTargetProgress({
    super.key,
    required this.target,
    required this.now,
  });

  final TemporaryTarget target;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final end = target.createdAt.add(Duration(minutes: target.duration));
    final remaining = StatusTimeline(
      start: target.createdAt,
      end: end,
      now: now,
    ).remainingMinutes!;
    return StatusTimeProgress(
      startedAt: target.createdAt,
      endsAt: end,
      now: now,
      label: context.lang.dashboardActivityTargetRemaining(
        remaining,
        TimeOfDay.fromDateTime(end.toLocal()).format(context),
      ),
    );
  }
}
