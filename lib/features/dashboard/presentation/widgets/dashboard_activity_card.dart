import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/common/controllers/activity_actions_controller.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../common/utils/run_dashboard_status_action.dart';
import '../../common/widgets/connected_status_cards.dart';
import '../../common/widgets/status_info_panel.dart';
import 'activity_target_preparation_details.dart';
import 'dashboard_activity_details.dart';
import 'dashboard_target_actions.dart';

class DashboardActivityCard extends ConsumerWidget {
  const DashboardActivityCard({
    super.key,
    required this.activity,
    required this.now,
    this.target,
  });
  final ActivityLogSummaryData activity;
  final DateTime now;
  final TemporaryTarget? target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned = activity.startedAt.isAfter(now);
    final busy = ref.watch(activityActionsControllerProvider).isLoading;
    return ConnectedStatusCards(
      primary: StatusInfoCard(
        icon: Icons.directions_run_rounded,
        title: activity.activityName,
        details: DashboardActivityDetails(activity: activity, now: now),
        trailing: IconButton(
          tooltip: planned
              ? context.lang.dashboardCancelPlannedActivity
              : context.lang.dashboardFinishActivityTooltip,
          icon: Icon(
            planned ? Icons.event_busy_rounded : Icons.stop_circle_outlined,
          ),
          onPressed: busy
              ? null
              : () => runDashboardStatusAction(
                  context,
                  () => ref
                      .read(activityActionsControllerProvider.notifier)
                      .end(activity),
                ),
        ),
      ),
      secondary: target == null
          ? null
          : StatusInfoPanel(
              icon: Icons.track_changes_rounded,
              trailing: DashboardTargetActions(target: target!),
              child: ActivityTargetPreparationDetails(
                target: target!,
                now: now,
                preparing: planned,
              ),
            ),
    );
  }
}
