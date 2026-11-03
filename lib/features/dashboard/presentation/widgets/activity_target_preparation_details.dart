import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/temporary_target.dart';
import 'dashboard_target_progress.dart';

class ActivityTargetPreparationDetails extends StatelessWidget {
  const ActivityTargetPreparationDetails({
    super.key,
    required this.target,
    required this.now,
    required this.preparing,
  });

  final TemporaryTarget target;
  final DateTime now;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preparing
              ? context.lang.dashboardActivityPreparationTarget(
                  target.targetTop,
                )
              : context.lang.dashboardActivityOngoingTarget(target.targetTop),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DashboardTargetProgress(target: target, now: now),
      ],
    );
  }
}
