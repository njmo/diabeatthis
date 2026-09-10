class MealActivityContext {
  final int logId;
  final String name;
  final DateTime startedAt;

  /// Actual end only when it occurred before the context cutoff.
  final DateTime? endedAt;
  final DateTime recordedAt;
  final int? plannedDurationMinutes;

  /// Current activity settings; their historical revisions are not stored.
  final int percentagePre;
  final int percentagePost;
  const MealActivityContext({
    required this.logId,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.recordedAt,
    required this.plannedDurationMinutes,
    required this.percentagePre,
    required this.percentagePost,
  });
}
