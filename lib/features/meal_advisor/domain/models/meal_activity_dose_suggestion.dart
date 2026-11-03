enum MealActivityPhase { upcoming, ongoing, completed }

/// Percentage of the calculated bolus to give, never a reduction percentage.
class MealActivityDoseSuggestion {
  const MealActivityDoseSuggestion({
    required this.dosePercent,
    required this.activityName,
    required this.startedAt,
    required this.phase,
  });

  final int dosePercent;
  final String activityName;
  final DateTime startedAt;
  final MealActivityPhase phase;

  @override
  bool operator ==(Object other) =>
      other is MealActivityDoseSuggestion &&
      dosePercent == other.dosePercent &&
      activityName == other.activityName &&
      startedAt == other.startedAt &&
      phase == other.phase;

  @override
  int get hashCode => Object.hash(dosePercent, activityName, startedAt, phase);

  Map<String, Object?> toJson() => {
    'dosePercent': dosePercent,
    'activityName': activityName,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'phase': phase.name,
  };

  static MealActivityDoseSuggestion? fromJson(Object? value) {
    if (value is! Map) return null;
    final percent = value['dosePercent'];
    final name = value['activityName'];
    final start = value['startedAt'];
    final phase = MealActivityPhase.values
        .where((p) => p.name == value['phase'])
        .firstOrNull;
    if (percent is! int ||
        percent <= 0 ||
        percent > 100 ||
        name is! String ||
        start is! int ||
        phase == null) {
      return null;
    }
    return MealActivityDoseSuggestion(
      dosePercent: percent,
      activityName: name,
      startedAt: DateTime.fromMillisecondsSinceEpoch(start),
      phase: phase,
    );
  }
}
