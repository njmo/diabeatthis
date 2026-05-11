class ActivityLogDetailsData {
  final int id;
  final int activityId;
  final String activityName;
  final int percentagePre;
  final int percentagePost;
  final int? durationMinutes;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? intensity;
  final String? notes;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityLogDetailsData({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.percentagePre,
    required this.percentagePost,
    required this.durationMinutes,
    required this.startedAt,
    required this.endedAt,
    required this.intensity,
    required this.notes,
    required this.isSynced,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => endedAt == null;

  Duration? get duration {
    final end = endedAt;
    if (end == null) {
      return null;
    }
    return end.difference(startedAt);
  }
}
