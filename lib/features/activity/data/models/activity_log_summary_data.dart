class ActivityLogSummaryData {
  final int id;
  final String activityName;
  final int activityId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String? intensity;
  final String? notes;
  final DateTime? summarizedAt;

  bool get isSummarized => summarizedAt != null;

  const ActivityLogSummaryData({
    required this.id,
    required this.activityName,
    required this.activityId,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    this.intensity,
    this.notes,
    this.summarizedAt,
  });
}
