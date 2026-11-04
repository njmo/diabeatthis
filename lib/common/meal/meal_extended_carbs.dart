import '../../core/domain/model/meal_macro_summary.dart';
import '../../features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';

int mealExtendedCarbsFromMacros(MealMacroSummary? macros) {
  return mealExtendedCarbsFromNutrients(
    fatGrams: macros?.fatGrams ?? 0,
    proteinGrams: macros?.proteinGrams ?? 0,
  );
}

int mealExtendedCarbsFromNutrients({
  required double fatGrams,
  required double proteinGrams,
}) {
  return const WbtExtendedCarbsCalculator()
      .calculateFromMacros(fatGrams: fatGrams, proteinGrams: proteinGrams)
      .grams;
}
