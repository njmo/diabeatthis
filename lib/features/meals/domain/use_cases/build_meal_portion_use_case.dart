import '../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../data/models/meal_details_data.dart';

/// Compare at the same precision used by the meal UI, independent of locale.
bool mealPortionAmountsMatch(double left, double right) =>
    left.toStringAsFixed(1) == right.toStringAsFixed(1);

enum MealPortionStatus { planned, unconfirmed, asPlanned, consumed }

typedef MealPortionSummary = ({
  MealNutritionTotals? planned,
  MealNutritionTotals? consumed,
  MealNutritionTotals? nutrition,
  bool equal,
  MealPortionStatus status,
  List<MealIngredientDetailsData> ingredients,
  List<MealIngredientDetailsData> extras,
});

class BuildMealPortionUseCase {
  const BuildMealPortionUseCase();

  MealPortionSummary call(MealDetailsData details) {
    final planned = details.plannedNutritionTotals;
    final consumed = details.consumedSnapshot?.nutritionTotals;
    final equal =
        planned != null &&
        consumed != null &&
        [
          (planned.totalCarbsG, consumed.totalCarbsG),
          (planned.totalProteinG, consumed.totalProteinG),
          (planned.totalFatG, consumed.totalFatG),
          (planned.totalFiberG, consumed.totalFiberG),
          (planned.totalCaloriesKcal, consumed.totalCaloriesKcal),
          (planned.totalGrams, consumed.totalGrams),
        ].every((pair) => mealPortionAmountsMatch(pair.$1, pair.$2));
    final status = consumed == null
        ? const [
                'planned',
                'skipped',
                'interrupted',
              ].contains(details.meal.status)
              ? MealPortionStatus.planned
              : MealPortionStatus.unconfirmed
        : details.hasConsumedPlannedAmounts && equal
        ? MealPortionStatus.asPlanned
        : MealPortionStatus.consumed;
    return (
      planned: planned,
      consumed: consumed,
      nutrition: consumed ?? planned,
      equal: equal,
      status: status,
      ingredients: List.unmodifiable(
        details.ingredients.where((item) => !item.isExtra),
      ),
      extras: List.unmodifiable(
        details.ingredients.where((item) => item.isExtra),
      ),
    );
  }
}
