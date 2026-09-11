import '../../../../common/history/glucose_period_summary.dart';

/// Glucose-only projection; absence of unrelated source data is not implied.
class MealGlucoseAnalysis {
  final DateTime mealTime;
  final DateTime observedUntil;
  final DateTime expectedUntil;
  final GlucosePeriodSummary glucoseSummary;
  const MealGlucoseAnalysis({
    required this.mealTime,
    required this.observedUntil,
    required this.expectedUntil,
    required this.glucoseSummary,
  });
  bool get isTimeWindowComplete => !observedUntil.isBefore(expectedUntil);
}
