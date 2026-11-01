import '../../core/domain/model/meal_macro_summary.dart';

/// Nutrition values shared by saved meal records and a live planned preview.
class MealNutritionTotals {
  final double totalGrams;
  final double totalCarbsG;
  final double totalFiberG;
  final double totalNetCarbsG;
  final double totalFatG;
  final double totalProteinG;
  final double totalCaloriesKcal;

  const MealNutritionTotals({
    required this.totalGrams,
    required this.totalCarbsG,
    required this.totalFiberG,
    required this.totalNetCarbsG,
    required this.totalFatG,
    required this.totalProteinG,
    required this.totalCaloriesKcal,
  });

  factory MealNutritionTotals.fromMacroSummary(MealMacroSummary summary) {
    return MealNutritionTotals(
      totalGrams: summary.totalGrams,
      totalCarbsG: summary.carbsGrams,
      totalFiberG: summary.fiberGrams,
      totalNetCarbsG: summary.netCarbsGrams,
      totalFatG: summary.fatGrams,
      totalProteinG: summary.proteinGrams,
      totalCaloriesKcal: summary.totalKcal,
    );
  }

  double get wbtKcal => totalProteinG * 4 + totalFatG * 9;
}
