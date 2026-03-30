class MealSnapshot {
  final int mealId;
  final MealSnapshotType snapshotType;

  final double totalGrams;
  final double totalCarbsG;
  final double totalFiberG;
  final double totalNetCarbsG;
  final double totalFatG;
  final double totalProteinG;
  final double totalCaloriesKcal;

  final int ingredientsCount;
  final double? avgQuantityConfidence;
  final double? minQuantityConfidence;
  final double? carbWeightedQuantityConfidence;
  final double? wbtWeightedQuantityConfidence;
  final double? carbWeightedNutritionConfidence;
  final double? wbtWeightedNutritionConfidence;
  final double? carbWeightedEffectiveConfidence;
  final double? wbtWeightedEffectiveConfidence;

  const MealSnapshot({
    required this.mealId,
    required this.snapshotType,
    required this.totalGrams,
    required this.totalCarbsG,
    required this.totalFiberG,
    required this.totalNetCarbsG,
    required this.totalFatG,
    required this.totalProteinG,
    required this.totalCaloriesKcal,
    required this.ingredientsCount,
    required this.avgQuantityConfidence,
    required this.minQuantityConfidence,
    required this.carbWeightedQuantityConfidence,
    required this.wbtWeightedQuantityConfidence,
    required this.carbWeightedNutritionConfidence,
    required this.wbtWeightedNutritionConfidence,
    required this.carbWeightedEffectiveConfidence,
    required this.wbtWeightedEffectiveConfidence,
  });

  const MealSnapshot.initial({required mealId, required snapshotType})
      : this(
    mealId: mealId,
    snapshotType: snapshotType,
    totalGrams: 0,
    totalCarbsG: 0,
    totalFiberG: 0,
    totalNetCarbsG: 0,
    totalFatG: 0,
    totalProteinG: 0,
    totalCaloriesKcal: 0,
    ingredientsCount: 0,
    avgQuantityConfidence: null,
    minQuantityConfidence: null,
    carbWeightedQuantityConfidence: null,
    wbtWeightedQuantityConfidence: null,
    carbWeightedNutritionConfidence: null,
    wbtWeightedNutritionConfidence: null,
    carbWeightedEffectiveConfidence: null,
    wbtWeightedEffectiveConfidence: null,
  );
}

enum MealSnapshotType { planned, consumed }
