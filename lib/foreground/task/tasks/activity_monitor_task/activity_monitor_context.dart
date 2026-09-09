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
    this.finishReminderShown = false,
  });

  int? activityLogId;
  int? activityId;
  String? activityName;
  DateTime? startsAt;
  int? durationMinutes;
  bool finishReminderShown;

  bool get hasActivity => activityLogId != null && startsAt != null;

  void replaceWith(ActivityMonitorContext next) {
    activityLogId = next.activityLogId;
    activityId = next.activityId;
    activityName = next.activityName;
    startsAt = next.startsAt;
    durationMinutes = next.durationMinutes;
    finishReminderShown = next.finishReminderShown;
  }

  void clear() {
    activityLogId = null;
    activityId = null;
    activityName = null;
    startsAt = null;
    durationMinutes = null;
    finishReminderShown = false;
  }
}
