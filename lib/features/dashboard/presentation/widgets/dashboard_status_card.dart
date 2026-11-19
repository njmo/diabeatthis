import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/dashboard/dashboard_card_padding.dart';
import '../../../../common/temporary_targets/is_activity_temp_target_linked.dart';
import '../../../../common/temporary_targets/temp_target_policy.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../activity/common/controllers/activity_actions_controller.dart';
import '../../domain/models/dashboard_status_view_model.dart';
import '../controllers/dashboard_status_controller.dart';
import 'dashboard_activity_card.dart';
import 'dashboard_activity_target_card.dart';
import 'dashboard_completed_activity_card.dart';
import 'dashboard_meal_target_card.dart';
import 'dashboard_target_progress.dart';

class DashboardStatusCard extends ConsumerWidget {
  const DashboardStatusCard({super.key});
  static const int mealTargetValue = TempTargetPolicy.mealTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dashboardStatusViewModelProvider);
    ref.watch(activityActionsControllerProvider);
    ref.watch(dashboardStatusControllerProvider);
    return DashboardStatusCards(status: status);
  }
}

class DashboardStatusCards extends StatelessWidget {
  const DashboardStatusCards({
    super.key,
    required this.status,
    this.allowLocalActions = true,
    this.activityTrailing,
    this.activityRequestLabel,
  });

  final DashboardStatusViewModel status;
  final bool allowLocalActions;
  final Widget? activityTrailing;
  final String? activityRequestLabel;

  @override
  Widget build(BuildContext context) {
    if (status.loading) return const SizedBox.shrink();
    final activity = status.activity;
    final target = status.standaloneTarget;
    final cards = <Widget>[
      if (activity != null)
        DashboardActivityCard(
          activity: activity,
          allowLocalActions: allowLocalActions,
          trailing: activityTrailing,
          requestLabel: activityRequestLabel,
          now: status.now,
          target: status.linkedCompletedActivityId == null
              ? status.linkedTarget
              : null,
        ),
      for (final completed in status.completedActivities)
        DashboardCompletedActivityCard(
          activity: completed,
          allowLocalActions: allowLocalActions,
          now: status.now,
          target: completed.id == status.linkedCompletedActivityId
              ? status.linkedTarget
              : null,
        ),
      if (target != null && isActivityTempTarget(target))
        DashboardActivityTargetCard(
          target: target,
          now: status.now,
          canAttach: status.canAttachActivity,
          allowLocalActions: allowLocalActions,
        ),
      if (target != null &&
          target.targetTop == DashboardStatusCard.mealTargetValue)
        DashboardMealTargetCard(
          target: target,
          now: status.now,
          allowLocalActions: allowLocalActions,
        ),
      if (target != null &&
          !allowLocalActions &&
          !isActivityTempTarget(target) &&
          target.targetTop != DashboardStatusCard.mealTargetValue)
        StatusInfoCard(
          icon: Icons.track_changes_rounded,
          title: context.lang.caregiverTargetRange(
            target.targetBottom.toString(),
            target.targetTop.toString(),
          ),
          details: DashboardTargetProgress(target: target, now: status.now),
        ),
    ];
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          DashboardCardPadding(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
