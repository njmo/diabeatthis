import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../core/domain/model/temporary_target.dart';

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
    final endsAt = target.createdAt.add(Duration(minutes: target.duration));
    final remaining = TempTargetPolicy.minutesUntil(
      now,
      endsAt,
    ).clamp(0, target.duration);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.track_changes_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preparing
                    ? context.lang.dashboardActivityPreparationTarget(
                        target.targetTop,
                      )
                    : context.lang.dashboardActivityOngoingTarget(
                        target.targetTop,
                      ),
              ),
              Text(
                context.lang.dashboardActivityTargetRemaining(
                  remaining,
                  TimeOfDay.fromDateTime(endsAt).format(context),
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
