import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';

class CalculateIngredientReviewUseCase {
  const CalculateIngredientReviewUseCase();

  IngredientReviewNutrition call(
    IngredientDraft ingredient,
    double totalGrams,
  ) {
    final factor = totalGrams / 100;
    final carbs = calculateNetCarbs(
      carbs: ingredient.carbsPer100g * factor,
      fiber: ingredient.fiberPer100g * factor,
      labelMode: ingredient.carbsLabelMode,
    );
    final protein = ingredient.proteinPer100g * factor;
    final fat = ingredient.fatPer100g * factor;
    return IngredientReviewNutrition(
      carbs: carbs,
      protein: protein,
      fat: fat,
      extendedCarbs: const WbtExtendedCarbsCalculator()
          .calculateFromMacros(fatGrams: fat, proteinGrams: protein)
          .grams,
      calories:
          (ingredient.carbsPer100g * 4 +
              ingredient.proteinPer100g * 4 +
              ingredient.fatPer100g * 9) *
          factor,
    );
  }
}

class IngredientReviewNutrition {
  const IngredientReviewNutrition({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.extendedCarbs,
    required this.calories,
  });
  final double carbs;
  final double protein;
  final double fat;
  final int extendedCarbs;
  final double calories;
}
