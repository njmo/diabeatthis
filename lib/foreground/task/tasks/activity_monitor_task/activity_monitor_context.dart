class ActivityMonitorContext {
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
