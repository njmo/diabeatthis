import '../../../../core/domain/model/meal_macro_summary.dart';
import '../models/meal_summary_draft.dart';
import 'meal_summary_carbs_delta.dart';

class MealSummaryNutritionComparison {
  const MealSummaryNutritionComparison({
    required this.planned,
    required this.consumed,
    required this.hasKnownMass,
  });

  final MealMacroSummary planned;
  final MealMacroSummary consumed;
  final bool hasKnownMass;
}

MealSummaryNutritionComparison calculateMealSummaryNutritionComparison(
  MealSummaryDraft draft,
) {
  return MealSummaryNutritionComparison(
    planned: mealSummaryNutritionTotals(draft, planned: true),
    consumed: mealSummaryNutritionTotals(draft, planned: false),
    hasKnownMass: draft.itemsById.values.every(
      (item) => item.gramsPerAmount != null,
    ),
  );
}

MealMacroSummary mealSummaryNutritionTotals(
  MealSummaryDraft draft, {
  required bool planned,
}) {
  var carbs = 0.0;
  var netCarbs = 0.0;
  var fat = 0.0;
  var protein = 0.0;
  var fiber = 0.0;
  var grams = 0.0;
  for (final item in draft.itemsById.values) {
    final amount = planned
        ? (item.isExtra ? 0.0 : item.plannedAmount)
        : item.consumedAmount;
    carbs += amount * (item.carbsPerAmount ?? item.netCarbsPerAmount);
    netCarbs += amount * item.netCarbsPerAmount;
    fat += amount * item.fatPerAmount;
    protein += amount * item.proteinPerAmount;
    fiber += amount * item.fiberPerAmount;
    grams += amount * (item.gramsPerAmount ?? 0);
  }
  if (!planned) {
    for (final item in draft.extraItems) {
      final extraGrams = calculateMealIngredientDraftGrams(item);
      carbs += extraGrams * item.ingredient.carbsPer100g / 100;
      netCarbs += calculateExtraItemNetCarbs(item);
      fat += extraGrams * item.ingredient.fatPer100g / 100;
      protein += extraGrams * item.ingredient.proteinPer100g / 100;
      fiber += extraGrams * item.ingredient.fiberPer100g / 100;
      grams += extraGrams;
    }
  }
  return MealMacroSummary(
    carbsGrams: carbs,
    netCarbsGrams: netCarbs,
    fatGrams: fat,
    proteinGrams: protein,
    fiberGrams: fiber,
    totalGrams: grams,
  );
}
