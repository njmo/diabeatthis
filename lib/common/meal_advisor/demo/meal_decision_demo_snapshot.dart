/// Sample values only. Never used as inputs to a therapy action.
class MealDecisionDemoSnapshot {
  const MealDecisionDemoSnapshot({
    required this.capturedAt,
    this.glucose = 102,
    this.delta = -1,
    this.direction = 'Flat',
    this.iob = 1.2,
    this.cob = 18,
    this.carbs = 34,
    this.extendedCarbs = 0,
    this.protein = 8,
    this.fat = 6,
    this.targetGlucose = 100,
    this.targetStartedAt,
    this.targetEndedAt,
    this.extendedCarbsRemaining = 12,
    this.extendedCarbsRemainingMinutes = 45,
  });
  final DateTime capturedAt;
  final double? targetGlucose;
  final DateTime? targetStartedAt, targetEndedAt;
  final double extendedCarbsRemaining;
  final int extendedCarbsRemainingMinutes;
  final int glucose;

  /// Change since the previous simulated reading, five minutes earlier.
  final int delta;
  final String direction;
  final double iob, cob, carbs, extendedCarbs, protein, fat;
}
