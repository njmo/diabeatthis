import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/temporary_targets/is_activity_temp_target_linked.dart';
import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../activity/common/controllers/activity_actions_controller.dart';
import '../controllers/dashboard_status_controller.dart';
import 'dashboard_activity_card.dart';
import 'dashboard_activity_target_card.dart';
import 'dashboard_meal_target_card.dart';

class DashboardStatusCard extends ConsumerWidget {
  const DashboardStatusCard({super.key});
  static const int mealTargetValue = TempTargetPolicy.mealTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dashboardStatusViewModelProvider);
    ref.watch(activityActionsControllerProvider);
    ref.watch(dashboardStatusControllerProvider);
    if (status.loading) return const SizedBox.shrink();
    final activity = status.activity;
    final target = status.standaloneTarget;
    final cards = <Widget>[
      if (activity != null)
        DashboardActivityCard(
          activity: activity,
          now: status.now,
          target: status.linkedTarget,
        ),
      if (target != null && isActivityTempTarget(target))
        DashboardActivityTargetCard(
          target: target,
          now: status.now,
          canAttach: status.canAttachActivity,
        ),
      if (target != null && target.targetTop == mealTargetValue)
        DashboardMealTargetCard(target: target, now: status.now),
    ];
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: cards[i],
          ),
          if (i < cards.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
