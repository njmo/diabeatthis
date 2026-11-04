import '../../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../../core/domain/model/net_carbs_calculator.dart';
import '../../drafts/meal_draft.dart';

/// Aggregates raw values once; presentation decides how to round them.
class CalculateMealDraftNutritionUseCase {
  const CalculateMealDraftNutritionUseCase({required this.resolveGrams});

  final Future<double> Function(MealIngredientsDraft) resolveGrams;

  Future<MealMacroSummary> call(List<MealIngredientsDraft> ingredients) async {
    var grams = 0.0;
    var carbs = 0.0;
    var netCarbs = 0.0;
    var fiber = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    for (final row in ingredients) {
      final weight = await resolveGrams(row);
      final factor = weight / 100;
      final ingredient = row.ingredient;
      grams += weight;
      carbs += ingredient.carbsPer100g * factor;
      netCarbs += calculateNetCarbs(
        carbs: ingredient.carbsPer100g * factor,
        fiber: ingredient.fiberPer100g * factor,
        labelMode: ingredient.carbsLabelMode,
      );
      fiber += ingredient.fiberPer100g * factor;
      protein += ingredient.proteinPer100g * factor;
      fat += ingredient.fatPer100g * factor;
    }
    return MealMacroSummary(
      carbsGrams: carbs,
      netCarbsGrams: netCarbs,
      fiberGrams: fiber,
      proteinGrams: protein,
      fatGrams: fat,
      totalGrams: grams,
    );
  }
}
