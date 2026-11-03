import '../../../../common/monitoring/is_temporary_target_active.dart';
import '../../../../common/temporary_targets/is_activity_temp_target_linked.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';
import '../../../activity/domain/activity_schedule_time.dart';
import '../models/dashboard_status_view_model.dart';

class BuildDashboardStatusUseCase {
  const BuildDashboardStatusUseCase();

  DashboardStatusViewModel call({
    required DateTime now,
    required ActivityLogSummaryData? pendingActivity,
    required TemporaryTarget? target,
    bool loading = false,
  }) {
    if (loading) return DashboardStatusViewModel(now: now, loading: true);
    final visible =
        pendingActivity != null &&
        pendingActivity.endedAt == null &&
        !pendingActivity.startedAt.isAfter(
          now.add(activityPreparationLeadTime),
        );
    final activeTarget = isTemporaryTargetActive(target, at: now)
        ? target
        : null;
    final linked =
        activeTarget != null &&
        isActivityTempTargetLinked(
          activityVisible: visible,
          target: activeTarget,
          now: now,
        );
    return DashboardStatusViewModel(
      now: now,
      activity: visible ? pendingActivity : null,
      linkedTarget: linked ? activeTarget : null,
      standaloneTarget: linked ? null : activeTarget,
      canAttachActivity: !visible,
    );
  }
}
