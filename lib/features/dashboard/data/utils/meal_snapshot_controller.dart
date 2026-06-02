import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal_snapshot.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../../core/drift/mappers/meal_snapshot_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';

class MealSnapshotController with Logging {
  final Ref ref;

  MealSnapshotController({required this.ref});

  Future<void> createPlannedSnapshot(int mealId) async {
    final mealIngredients = await ref.read(
      getMealIngredientsDraftForMealProvider(mealId).future,
    );
    final summary = await ref.read(
      mealMacronutrientsSummaryProvider(mealId).future,
    );

    if (summary == null) {
      logI('Summary is null, no data to create snapshot');
      return;
    }

    var minQuantityConfidence = 1.0;
    var quantityConfidenceSum = 0.0;
    var carbWeightedQuantityConfidence = 0.0;
    var wbtWeightedQuantityConfidence = 0.0;
    var carbWeightedNutritionConfidence = 0.0;
    var wbtWeightedNutritionConfidence = 0.0;
    var carbWeightedEffectiveConfidence = 0.0;
    var wbtWeightedEffectiveConfidence = 0.0;

    for (final mealIngredient in mealIngredients) {
      final itemQuantityConfidence = mealIngredient.quantityConfidence;
      final nutritionConfidence = mealIngredient.ingredient.nutritionConfidence;
      final effectiveConfidence = itemQuantityConfidence * nutritionConfidence;
      final double grams;
      if (mealIngredient.ingredient.isReference) {
        grams = mealIngredient.amount * 100.0;
      } else {
        grams = mealIngredient.ingredientPortion.portion.map(
          empty: (_) => mealIngredient.amount.toDouble(),
          existing: (_) =>
              mealIngredient.ingredientPortion.amount *
              mealIngredient.amount.toDouble(),
          draft: (_) => throw UnimplementedError(),
        );
      }
      final proteinG = grams * mealIngredient.ingredient.proteinPer100g / 100.0;
      final fatG = grams * mealIngredient.ingredient.fatPer100g / 100.0;
      final netCarbsG = calculateNetCarbs(
        carbs: grams * mealIngredient.ingredient.carbsPer100g / 100.0,
        fiber: grams * mealIngredient.ingredient.fiberPer100g / 100.0,
        labelMode: mealIngredient.ingredient.carbsLabelMode,
      );

      final wbtKcal = proteinG * 4 + fatG * 9;

      quantityConfidenceSum += itemQuantityConfidence;

      if (itemQuantityConfidence < minQuantityConfidence) {
        minQuantityConfidence = itemQuantityConfidence;
      }
      carbWeightedQuantityConfidence += itemQuantityConfidence * netCarbsG;
      wbtWeightedQuantityConfidence += itemQuantityConfidence * wbtKcal;
      carbWeightedNutritionConfidence += nutritionConfidence * netCarbsG;
      wbtWeightedNutritionConfidence += nutritionConfidence * wbtKcal;
      carbWeightedEffectiveConfidence += effectiveConfidence * netCarbsG;
      wbtWeightedEffectiveConfidence += effectiveConfidence * wbtKcal;
    }

    final totalWbtKcal = summary.fatGrams * 9 + summary.proteinGrams * 4;

    final snapshot = MealSnapshot(
      mealId: mealId,
      snapshotType: MealSnapshotType.planned,
      totalGrams: summary.totalGrams,
      totalFatG: summary.fatGrams,
      totalCarbsG: summary.carbsGrams,
      totalFiberG: summary.fiberGrams,
      totalProteinG: summary.proteinGrams,
      totalNetCarbsG: summary.netCarbsGrams,
      totalCaloriesKcal: summary.totalKcal,
      ingredientsCount: mealIngredients.length,
      avgQuantityConfidence: mealIngredients.isNotEmpty
          ? quantityConfidenceSum / mealIngredients.length
          : null,
      minQuantityConfidence: mealIngredients.isNotEmpty
          ? minQuantityConfidence
          : null,
      carbWeightedQuantityConfidence: summary.netCarbsGrams > 0
          ? carbWeightedQuantityConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedQuantityConfidence: totalWbtKcal > 0
          ? wbtWeightedQuantityConfidence / totalWbtKcal
          : null,
      carbWeightedNutritionConfidence: summary.netCarbsGrams > 0
          ? carbWeightedNutritionConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedNutritionConfidence: totalWbtKcal > 0
          ? wbtWeightedNutritionConfidence / totalWbtKcal
          : null,
      carbWeightedEffectiveConfidence: summary.netCarbsGrams > 0
          ? carbWeightedEffectiveConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedEffectiveConfidence: totalWbtKcal > 0
          ? wbtWeightedEffectiveConfidence / totalWbtKcal
          : null,
    );

    final db = ref.read(databaseProvider);
    await db
        .into(db.mealSnapshot)
        .insertOnConflictUpdate(snapshot.toCompanion());
  }

  Future<void> saveConsumedSnapshot(int mealId) async {
    final mealIngredients = await ref.read(
      getMealIngredientsDraftForMealProvider(mealId).future,
    );
    final summary = await ref.read(
      mealMacronutrientsConsumedSummaryProvider(mealId).future,
    );

    if (summary == null) {
      logI('Summary is null, no data to create snapshot');
      return;
    }

    var minQuantityConfidence = 1.0;
    var quantityConfidenceSum = 0.0;
    var carbWeightedQuantityConfidence = 0.0;
    var wbtWeightedQuantityConfidence = 0.0;
    var carbWeightedNutritionConfidence = 0.0;
    var wbtWeightedNutritionConfidence = 0.0;
    var carbWeightedEffectiveConfidence = 0.0;
    var wbtWeightedEffectiveConfidence = 0.0;
    var consumedIngredientsCount = 0;

    for (final mealIngredient in mealIngredients) {
      final amount = mealIngredient.entryType == 'extra'
          ? (mealIngredient.consumedAmount ?? 0)
          : (mealIngredient.consumedAmount ?? mealIngredient.amount);
      if (amount <= 0) continue;
      final consumedConfidence = mealIngredient.consumedConfidence ?? 1.0;

      final itemQuantityConfidence = mealIngredient.entryType == 'extra'
          ? consumedConfidence
          : mealIngredient.quantityConfidence * consumedConfidence;
      consumedIngredientsCount++;
      final nutritionConfidence = mealIngredient.ingredient.nutritionConfidence;
      final effectiveConfidence = itemQuantityConfidence * nutritionConfidence;
      final double grams;
      if (mealIngredient.ingredient.isReference) {
        grams = amount * 100.0;
      } else {
        grams = mealIngredient.ingredientPortion.portion.map(
          empty: (_) => amount,
          existing: (_) => mealIngredient.ingredientPortion.amount * amount,
          draft: (_) => throw UnimplementedError(),
        );
      }

      final proteinG = grams * mealIngredient.ingredient.proteinPer100g / 100.0;
      final fatG = grams * mealIngredient.ingredient.fatPer100g / 100.0;
      final netCarbsG = calculateNetCarbs(
        carbs: grams * mealIngredient.ingredient.carbsPer100g / 100.0,
        fiber: grams * mealIngredient.ingredient.fiberPer100g / 100.0,
        labelMode: mealIngredient.ingredient.carbsLabelMode,
      );

      final wbtKcal = proteinG * 4 + fatG * 9;

      quantityConfidenceSum += itemQuantityConfidence;

      if (itemQuantityConfidence < minQuantityConfidence) {
        minQuantityConfidence = itemQuantityConfidence;
      }
      carbWeightedQuantityConfidence += itemQuantityConfidence * netCarbsG;
      wbtWeightedQuantityConfidence += itemQuantityConfidence * wbtKcal;
      carbWeightedNutritionConfidence += nutritionConfidence * netCarbsG;
      wbtWeightedNutritionConfidence += nutritionConfidence * wbtKcal;
      carbWeightedEffectiveConfidence += effectiveConfidence * netCarbsG;
      wbtWeightedEffectiveConfidence += effectiveConfidence * wbtKcal;
    }

    if (consumedIngredientsCount == 0) {
      logI('No consumed ingredients, skipping snapshot');
      return;
    }

    final totalWbtKcal = summary.fatGrams * 9 + summary.proteinGrams * 4;

    final snapshot = MealSnapshot(
      mealId: mealId,
      snapshotType: MealSnapshotType.consumed,
      totalGrams: summary.totalGrams,
      totalFatG: summary.fatGrams,
      totalCarbsG: summary.carbsGrams,
      totalFiberG: summary.fiberGrams,
      totalProteinG: summary.proteinGrams,
      totalNetCarbsG: summary.netCarbsGrams,
      totalCaloriesKcal: summary.totalKcal,
      ingredientsCount: consumedIngredientsCount,
      avgQuantityConfidence: quantityConfidenceSum / consumedIngredientsCount,
      minQuantityConfidence: minQuantityConfidence,
      carbWeightedQuantityConfidence: summary.netCarbsGrams > 0
          ? carbWeightedQuantityConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedQuantityConfidence: totalWbtKcal > 0
          ? wbtWeightedQuantityConfidence / totalWbtKcal
          : null,
      carbWeightedNutritionConfidence: summary.netCarbsGrams > 0
          ? carbWeightedNutritionConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedNutritionConfidence: totalWbtKcal > 0
          ? wbtWeightedNutritionConfidence / totalWbtKcal
          : null,
      carbWeightedEffectiveConfidence: summary.netCarbsGrams > 0
          ? carbWeightedEffectiveConfidence / summary.netCarbsGrams
          : null,
      wbtWeightedEffectiveConfidence: totalWbtKcal > 0
          ? wbtWeightedEffectiveConfidence / totalWbtKcal
          : null,
    );

    final db = ref.read(databaseProvider);
    await db
        .into(db.mealSnapshot)
        .insertOnConflictUpdate(snapshot.toCompanion());
  }

  Future<void> finalizeMealSummary(int mealId) async {}

  Future<MealSnapshot?> getMealSnapshotByType(
    int mealId,
    MealSnapshotType type,
  ) {
    return Future.value(null);
  }
}
