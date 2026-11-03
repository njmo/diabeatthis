import '../../../../common/nutrition/nutrition_revision_comparison.dart';
import '../models/meal_details_data.dart';

class MealNutritionRevisionMapper {
  const MealNutritionRevisionMapper();

  List<NutritionRevisionComparison> map(MealDetailsData details) {
    if (!details.meal.isEaten) return const [];
    return [
      for (final ingredient in details.ingredients)
        if ((details.hasConsumedData
                    ? ingredient.consumedTotalGrams
                    : ingredient.isExtra
                    ? 0
                    : ingredient.plannedTotalGrams) >
                0 &&
            (ingredient.historicalNutritionUnavailable ||
                (details.hasConsumedData
                    ? ingredient.consumedNutritionDiffersFromCurrent
                    : ingredient.plannedNutritionDiffersFromCurrent)))
          NutritionRevisionComparison(
            recordedAsOf:
                details.preferredSummarySnapshot?.createdAt ??
                (details.hasConsumedData
                    ? ingredient.createdAt
                    : details.meal.createdAt),
            currentUpdatedAt: ingredient.currentNutrition.effectiveAt,
            ingredientId: ingredient.ingredientId,
            name: ingredient.ingredientName,
            grams: details.hasConsumedData
                ? ingredient.consumedTotalGrams
                : ingredient.plannedTotalGrams,
            recordedPer100g: values(
              details.hasConsumedData
                  ? ingredient.consumedNutrition
                  : ingredient.plannedNutrition,
            ),
            currentPer100g: values(ingredient.currentNutrition),
            recordedConfidence:
                (details.hasConsumedData
                        ? ingredient.consumedNutrition
                        : ingredient.plannedNutrition)
                    .nutritionConfidence,
            currentConfidence: ingredient.currentNutrition.nutritionConfidence,
            historicalUnavailable: ingredient.historicalNutritionUnavailable,
          ),
    ];
  }

  Map<String, double> values(IngredientNutritionData data) => {
    'net_carbs_g': data.safeNetCarbsPer100g,
    'fat_g': data.fatPer100g,
    'protein_g': data.proteinPer100g,
    'fiber_g': data.fiberPer100g,
  };
}
