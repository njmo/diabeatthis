import 'package:flutter/material.dart';

import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../common/widgets/connected_status_cards.dart';
import '../../common/widgets/status_info_panel.dart';
import 'activity_target_preparation_details.dart';
import 'dashboard_completed_activity_details.dart';
import 'dashboard_target_actions.dart';

class DashboardCompletedActivityCard extends StatelessWidget {
  const DashboardCompletedActivityCard({
    super.key,
    required this.activity,
    required this.now,
    this.target,
  });
  final ActivityLogSummaryData activity;
  final DateTime now;
  final TemporaryTarget? target;

  @override
  Widget build(BuildContext context) => activity.isSummarized
      ? const SizedBox.shrink()
      : ConnectedStatusCards(
          primary: StatusInfoPanel(
            icon: Icons.sports_score,
            child: DashboardCompletedActivityDetails(activity: activity),
          ),
          secondary: target == null
              ? null
              : StatusInfoPanel(
                  icon: Icons.track_changes_rounded,
                  trailing: DashboardTargetActions(target: target!),
                  child: ActivityTargetPreparationDetails(
                    target: target!,
                    now: now,
                    preparing: false,
                  ),
                ),
        );
}
