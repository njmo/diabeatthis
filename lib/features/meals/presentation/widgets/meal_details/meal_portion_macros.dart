import 'package:flutter/material.dart';

import '../../../../../common/nutrition/meal_nutrition_totals.dart';
import '../../../../../common/widgets/meal_macro_summary.dart';

class MealPortionMacros extends StatelessWidget {
  const MealPortionMacros({super.key, required this.nutrition});
  final MealNutritionTotals nutrition;

  @override
  Widget build(BuildContext context) => MealMacroSummary(
    netCarbs: nutrition.totalNetCarbsG,
    protein: nutrition.totalProteinG,
    fat: nutrition.totalFatG,
    fiber: nutrition.totalFiberG,
    calories: nutrition.totalCaloriesKcal,
    weightGrams: nutrition.totalGrams,
  );
}
