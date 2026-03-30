import 'package:drift/drift.dart' as d;

import '../../domain/model/meal_snapshot.dart' as domain;
import '../database_impl.dart';

extension MealSnapshotDataToDomain on MealSnapshotData {
  domain.MealSnapshot toDomain() => domain.MealSnapshot(
    mealId: mealId,
    snapshotType: (snapshotType == 'planned') ? domain.MealSnapshotType.planned : domain.MealSnapshotType.consumed,
    totalGrams: totalGrams,
    totalCarbsG: totalCarbsG,
    totalFiberG: totalFiberG,
    totalNetCarbsG: totalNetCarbsG,
    totalFatG: totalFatG,
    totalProteinG: totalProteinG,
    totalCaloriesKcal: totalCaloriesKcal,
    ingredientsCount: ingredientsCount,
    avgQuantityConfidence: avgQuantityConfidence,
    minQuantityConfidence: minQuantityConfidence,
    carbWeightedQuantityConfidence: carbWeightedQuantityConfidence,
    wbtWeightedQuantityConfidence: wbtWeightedQuantityConfidence,
    carbWeightedNutritionConfidence: carbWeightedNutritionConfidence,
    wbtWeightedNutritionConfidence: wbtWeightedNutritionConfidence,
    carbWeightedEffectiveConfidence: carbWeightedEffectiveConfidence,
    wbtWeightedEffectiveConfidence: wbtWeightedEffectiveConfidence,
  );
}

extension DomainMealSnapshotToCompanion on domain.MealSnapshot {
  MealSnapshotCompanion toCompanion() {
    return MealSnapshotCompanion(
      mealId: d.Value(mealId),
      snapshotType: d.Value(snapshotType == domain.MealSnapshotType.planned ? 'planned' : 'consumed'),
      totalGrams: d.Value(totalGrams),
      totalCarbsG: d.Value(totalCarbsG),
      totalFiberG: d.Value(totalFiberG),
      totalNetCarbsG: d.Value(totalNetCarbsG),
      totalFatG: d.Value(totalFatG),
      totalProteinG: d.Value(totalProteinG),
      totalCaloriesKcal: d.Value(totalCaloriesKcal),
      ingredientsCount: d.Value(ingredientsCount),
      avgQuantityConfidence: d.Value(avgQuantityConfidence),
      minQuantityConfidence: d.Value(minQuantityConfidence),
      carbWeightedQuantityConfidence: d.Value(carbWeightedQuantityConfidence),
      wbtWeightedQuantityConfidence: d.Value(wbtWeightedQuantityConfidence),
      carbWeightedNutritionConfidence: d.Value(carbWeightedNutritionConfidence),
      wbtWeightedNutritionConfidence: d.Value(wbtWeightedNutritionConfidence),
      carbWeightedEffectiveConfidence: d.Value(carbWeightedEffectiveConfidence),
      wbtWeightedEffectiveConfidence: d.Value(wbtWeightedEffectiveConfidence),
    );
  }
}