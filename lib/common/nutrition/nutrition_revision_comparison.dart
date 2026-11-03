/// Compares data quality, never the observed effectiveness of a meal.
class NutritionRevisionComparison {
  final DateTime? recordedAsOf;
  final DateTime? currentUpdatedAt;
  final int ingredientId;
  final String name;
  final double grams;
  final Map<String, double> recordedPer100g;
  final Map<String, double> currentPer100g;
  final double recordedConfidence;
  final double currentConfidence;
  final bool historicalUnavailable;

  const NutritionRevisionComparison({
    this.recordedAsOf,
    this.currentUpdatedAt,
    required this.ingredientId,
    required this.name,
    required this.grams,
    required this.recordedPer100g,
    required this.currentPer100g,
    required this.recordedConfidence,
    required this.currentConfidence,
    required this.historicalUnavailable,
  });

  bool get confidenceIncreased =>
      !historicalUnavailable && currentConfidence > recordedConfidence;

  Map<String, Object?> toJson() => {
    'ingredient_id': ingredientId,
    'recorded_as_of': recordedAsOf?.toUtc().toIso8601String(),
    'current_data_updated_at': currentUpdatedAt?.toUtc().toIso8601String(),
    'name': name,
    'recorded_quantity_g': grams,
    'historical_data_available': !historicalUnavailable,
    'recorded_per_100g': historicalUnavailable ? null : recordedPer100g,
    'current_per_100g': currentPer100g,
    'recorded_nutrition_confidence': historicalUnavailable
        ? null
        : recordedConfidence,
    'current_nutrition_confidence': currentConfidence,
    'confidence_increased': historicalUnavailable ? null : confidenceIncreased,
    'net_carbs_difference_for_recorded_quantity_g': historicalUnavailable
        ? null
        : (currentPer100g['net_carbs_g']! - recordedPer100g['net_carbs_g']!) *
              grams /
              100,
    'change_basis': 'unknown',
    'quantity_confidence_not_reassessed': true,
  };
}
