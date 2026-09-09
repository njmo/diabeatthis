import 'activity_monitoring_phase.dart';

class ActivityMonitoringStatus {
  const ActivityMonitoringStatus({
    required this.phase,
    this.activityLogId,
    this.name,
    this.startsAt,
  });
  final ActivityMonitoringPhase phase;
  final int? activityLogId;
  final String? name;
  final DateTime? startsAt;
  bool get isUnavailable => phase == ActivityMonitoringPhase.unavailable;

  @override
  bool operator ==(Object other) =>
      other is ActivityMonitoringStatus &&
      phase == other.phase &&
      activityLogId == other.activityLogId &&
      name == other.name &&
      startsAt == other.startsAt;

  @override
  int get hashCode => Object.hash(phase, activityLogId, name, startsAt);

  bool get isCurrent =>
      !isUnavailable &&
      phase != ActivityMonitoringPhase.initializing &&
      phase != ActivityMonitoringPhase.idle &&
      phase != ActivityMonitoringPhase.planned;
}
