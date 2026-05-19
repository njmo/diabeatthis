class ActivityLogSummaryData {
  final int id;
  final String activityName;
  final int activityId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;

  const ActivityLogSummaryData({
    required this.id,
    required this.activityName,
    required this.activityId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
  });
}
