import '../../../../core/domain/model/low_treatment_context.dart';

/// A saved consumption entry, distinct from an unaccepted AAPS suggestion.
class RecordedLowTreatment {
  final List<({String name, double grams})> ingredients;
  final int mealId;
  final DateTime eatenAt;
  final double? netCarbsGrams;
  final double? historicalNutritionCarbsGrams;
  final bool historicalNutritionUnavailable;
  final bool ingredientsAvailable;
  final bool snapshotHistoryAvailable;
  final LowTreatmentReason? reason;
  final LowTreatmentContextSource? source;
  final int? relatedMealId;
  final int? relatedActivityLogId;
  final double? suggestedCarbs;

  /// Precise nutrition for historical summaries; delivery retains its contract.
  double? get historicalCarbs => historicalNutritionUnavailable
      ? null
      : historicalNutritionCarbsGrams ?? netCarbsGrams;

  const RecordedLowTreatment({
    this.ingredients = const [],
    required this.mealId,
    required this.eatenAt,
    required this.netCarbsGrams,
    this.historicalNutritionCarbsGrams,
    this.historicalNutritionUnavailable = false,
    this.ingredientsAvailable = true,
    this.snapshotHistoryAvailable = true,
    this.reason,
    this.source,
    this.relatedMealId,
    this.relatedActivityLogId,
    this.suggestedCarbs,
  });
}
