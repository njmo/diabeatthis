import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../meal_analysis/domain/models/meal_composition.dart';
import '../../../meal_analysis/domain/models/similar_meal_query.dart';
import '../models/meal_details_data.dart';

class SimilarMealQueryMapper {
  const SimilarMealQueryMapper();

  SimilarMealQuery? map(MealDetailsData details) {
    final snapshot = details.preferredSummarySnapshot;
    if (snapshot == null) return null;

    final grams = <int, double>{};
    for (final ingredient in details.ingredients) {
      final amount = details.consumedSnapshot != null
          ? ingredient.consumedTotalGrams
          : ingredient.isExtra
          ? 0.0
          : ingredient.plannedTotalGrams;
      if (amount > 0) {
        grams[ingredient.ingredientId] =
            (grams[ingredient.ingredientId] ?? 0) + amount;
      }
    }

    return SimilarMealQuery(
      mealId: details.meal.id,
      asOf: details.analysisTime,
      target: MealMacroSummary(
        carbsGrams: snapshot.totalCarbsG,
        netCarbsGrams: snapshot.totalNetCarbsG,
        proteinGrams: snapshot.totalProteinG,
        fatGrams: snapshot.totalFatG,
        fiberGrams: snapshot.totalFiberG,
        totalGrams: snapshot.totalGrams,
      ),
      composition: MealComposition(grams),
    );
  }
}
