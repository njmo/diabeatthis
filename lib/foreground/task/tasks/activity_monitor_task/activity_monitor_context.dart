import '../../../../common/monitoring/activity_duration_source.dart';
import '../../../../common/monitoring/activity_monitoring_phase.dart';
import '../../../../common/monitoring/activity_monitoring_status.dart';
import '../../../event/internal/monitoring_status_changed.dart';
import '../../base/runtime_context.dart';

class ActivityMonitorContext {
  ActivityMonitoringStatus? _lastPublishedStatus;
  void publishStatus(RuntimeContext context, ActivityMonitoringPhase phase) {
    context.throwIfCancelled();
    final status = phase == ActivityMonitoringPhase.idle
        ? const ActivityMonitoringStatus(phase: ActivityMonitoringPhase.idle)
        : ActivityMonitoringStatus(
            phase: phase,
            activityLogId: activityLogId,
            name: activityName,
            startsAt: startsAt,
          );
    if (status == _lastPublishedStatus) return;
    _lastPublishedStatus = status;
    context.emitEvent(ActivityMonitoringStatusChanged(status));
  }

  ActivityMonitorContext({
    this.activityLogId,
    this.activityId,
    this.activityName,
    this.startsAt,
    this.durationMinutes,
    this.durationSource = ActivityDurationSource.supplied,
  });

  int? activityLogId;
  int? activityId;
  String? activityName;
  DateTime? startsAt;
  int? durationMinutes;
  ActivityDurationSource durationSource;

  bool get hasActivity => activityLogId != null && startsAt != null;

  void replaceWith(ActivityMonitorContext next) {
    activityLogId = next.activityLogId;
    activityId = next.activityId;
    activityName = next.activityName;
    startsAt = next.startsAt;
    durationMinutes = next.durationMinutes;
    durationSource = next.durationSource;
  }

  void clear() {
    activityLogId = null;
    activityId = null;
    activityName = null;
    startsAt = null;
    durationMinutes = null;
    durationSource = ActivityDurationSource.supplied;
  }
}
