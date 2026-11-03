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
    List<ActivityLogSummaryData> completedActivities = const [],
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
    ActivityLogSummaryData? linkedCompleted;
    if (activeTarget != null && isActivityTempTarget(activeTarget)) {
      for (final entry in completedActivities) {
        final end = entry.endedAt;
        if (end != null &&
            !activeTarget.createdAt.isAfter(end) &&
            activeTarget.createdAt
                .add(Duration(minutes: activeTarget.duration))
                .isAfter(entry.startedAt)) {
          linkedCompleted = entry;
          break;
        }
      }
    }
    final linked =
        linkedCompleted == null &&
        activeTarget != null &&
        isActivityTempTargetLinked(
          activityVisible: visible,
          target: activeTarget,
          now: now,
        );
    return DashboardStatusViewModel(
      now: now,
      activity: visible ? pendingActivity : null,
      linkedTarget: linked || linkedCompleted != null ? activeTarget : null,
      standaloneTarget: linked || linkedCompleted != null ? null : activeTarget,
      completedActivities: completedActivities,
      linkedCompletedActivityId: linkedCompleted?.id,
      canAttachActivity: !visible,
    );
  }
}
