class MealActivityObservation {
  final int logId;
  final String name;

  /// Original recorded start, including activities begun before the meal.
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? intensity;
  const MealActivityObservation({
    required this.logId,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    this.intensity,
  });
  Duration observedDuration(DateTime start, DateTime end) {
    final from = startedAt.isBefore(start) ? start : startedAt;
    final until = endedAt != null && endedAt!.isBefore(end) ? endedAt! : end;
    return until.isAfter(from) ? until.difference(from) : Duration.zero;
  }
}
