import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../meal_advisor/domain/models/meal_advisor_target.dart';
import '../../../meal_analysis/domain/models/meal_composition.dart';
import '../../../meal_analysis/domain/models/meal_record_evidence.dart';
import '../models/meal_details_data.dart';

class MealAdvisorTargetMapper {
  const MealAdvisorTargetMapper();
  MealAdvisorTarget map(
    MealDetailsData details,
    MealMacroSummary macros,
    DateTime asOf,
  ) {
    if ([
      macros.netCarbsGrams,
      macros.proteinGrams,
      macros.fatGrams,
      macros.fiberGrams,
      macros.totalGrams,
    ].any((v) => !v.isFinite || v < 0)) {
      throw StateError('Invalid planned macros');
    }
    if (details.meal.isLowTreatment || details.meal.isEaten) {
      throw StateError('A planned meal is required');
    }
    if (details.meal.updatedAt.isAfter(asOf) ||
        details.ingredients.any((i) => i.updatedAt.isAfter(asOf))) {
      throw StateError('Plan changed after context cutoff');
    }
    final grams = <int, double>{};
    final ingredients = <({String name, double grams})>[];
    for (final ingredient in details.ingredients) {
      if (ingredient.isExtra ||
          !ingredient.plannedTotalGrams.isFinite ||
          ingredient.plannedTotalGrams <= 0) {
        continue;
      }
      grams[ingredient.ingredientId] =
          (grams[ingredient.ingredientId] ?? 0) + ingredient.plannedTotalGrams;
      ingredients.add((
        name: ingredient.ingredientName,
        grams: ingredient.plannedTotalGrams,
      ));
    }
    final snapshot = details.plannedSnapshot;
    bool same(double a, double b) => (a - b).abs() < 0.000001;
    final usable =
        snapshot != null &&
        !snapshot.createdAt.isAfter(asOf) &&
        !snapshot.updatedAt.isAfter(asOf) &&
        details.ingredients.every(
          (i) => !i.updatedAt.isAfter(snapshot.updatedAt),
        ) &&
        same(snapshot.totalNetCarbsG, macros.netCarbsGrams) &&
        same(snapshot.totalFatG, macros.fatGrams) &&
        same(snapshot.totalProteinG, macros.proteinGrams) &&
        same(snapshot.totalFiberG, macros.fiberGrams) &&
        same(snapshot.totalGrams, macros.totalGrams);
    return MealAdvisorTarget(
      mealId: details.meal.id,
      name: details.meal.name,
      plannedAt: details.meal.plannedAt,
      macros: macros,
      composition: grams.isEmpty ? null : MealComposition(grams),
      ingredients: ingredients,
      confidence: !usable
          ? null
          : MealNutritionConfidence(
              carbsQuantity: snapshot.carbWeightedQuantityConfidence,
              carbsNutrition: snapshot.carbWeightedNutritionConfidence,
              carbsEffective: snapshot.carbWeightedEffectiveConfidence,
              fatProteinQuantity: snapshot.wbtWeightedQuantityConfidence,
              fatProteinNutrition: snapshot.wbtWeightedNutritionConfidence,
              fatProteinEffective: snapshot.wbtWeightedEffectiveConfidence,
            ),
    );
  }
}
