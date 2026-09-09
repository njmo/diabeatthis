import 'meal_monitoring_phase.dart';

class MealMonitoringStatus {
  const MealMonitoringStatus({
    required this.phase,
    this.mealId,
    this.name,
    this.plannedAt,
  });
  final MealMonitoringPhase phase;
  final int? mealId;
  final String? name;
  final DateTime? plannedAt;
  bool get isUnavailable => phase == MealMonitoringPhase.unavailable;

  @override
  bool operator ==(Object other) =>
      other is MealMonitoringStatus &&
      phase == other.phase &&
      mealId == other.mealId &&
      name == other.name &&
      plannedAt == other.plannedAt;

  @override
  int get hashCode => Object.hash(phase, mealId, name, plannedAt);

  bool get isCurrent =>
      !isUnavailable &&
      phase != MealMonitoringPhase.initializing &&
      phase != MealMonitoringPhase.idle &&
      phase != MealMonitoringPhase.planned;
}
