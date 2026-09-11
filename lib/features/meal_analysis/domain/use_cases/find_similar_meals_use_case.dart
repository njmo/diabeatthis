import 'dart:math' as math;

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../models/meal_composition.dart';
import '../models/meal_observation_window.dart';
import '../models/recorded_meal_context.dart';
import '../models/similar_meal_context.dart';

/// Searches saved snapshots only. No ingredient recalculation or clinical advice.
class FindSimilarMealsUseCase {
  static const lookback = Duration(days: 90);
  static const maximumMatches = 8;
  static const maximumPortionDifference = 0.25;
  static const maximumCompositionDifference = 0.2;

  final Future<List<RecordedMealContext>> Function(DateTime, DateTime, int?)
  loadMeals;
  const FindSimilarMealsUseCase({required this.loadMeals});

  Future<SimilarMealContext> call({
    required int mealId,
    required DateTime asOf,
    required MealMacroSummary target,
    MealComposition? composition,
  }) async {
    final targetComposition = composition;
    final start = asOf.subtract(lookback);
    final vector = [
      target.netCarbsGrams * 4,
      target.proteinGrams * 4,
      target.fatGrams * 9,
    ];
    final total = vector.fold(0.0, (a, b) => a + b);
    final matches = <SimilarMealMatch>[];
    if (vector.every((v) => v.isFinite && v >= 0) && total > 0) {
      final seen = <int>{};
      for (final meal in await loadMeals(start, asOf, mealId)) {
        final s = meal.snapshot;
        if (s == null ||
            meal.mealId == mealId ||
            !meal.eatenAt.isBefore(asOf) ||
            meal.eatenAt.isBefore(start) ||
            !seen.add(meal.mealId)) {
          continue;
        }
        // Only compare outcomes whose observation window ended before this meal.
        final window = MealObservationWindow.forWbtKcal(
          s.totalProteinG * 4 + s.totalFatG * 9,
        );
        if (meal.eatenAt.add(window).isAfter(asOf)) continue;
        final values = [
          s.totalNetCarbsG * 4,
          s.totalProteinG * 4,
          s.totalFatG * 9,
        ];
        if (values.any((v) => !v.isFinite || v < 0)) continue;
        final energy = values.fold(0.0, (a, b) => a + b);
        if (energy <= 0) continue;
        // Limit the energy difference to 25% of the larger portion.
        // Ratios alone would also match doubled meals.
        final size = (energy - total).abs() / math.max(energy, total);
        final macroDistance =
            List.generate(
              3,
              (i) => (vector[i] / total - values[i] / energy).abs(),
            ).fold(0.0, (a, b) => a + b) /
            2;
        final candidateComposition = meal.composition;
        final ingredientDistance = candidateComposition == null
            ? null
            : targetComposition?.distanceTo(candidateComposition);
        final sameIngredients =
            ingredientDistance != null &&
            ingredientDistance <= maximumCompositionDifference;
        if (!sameIngredients &&
            (size > maximumPortionDifference ||
                macroDistance > maximumCompositionDifference)) {
          continue;
        }
        matches.add(
          SimilarMealMatch(
            meal: meal,
            distance: sameIngredients
                ? ingredientDistance
                : (size + macroDistance) / 2,
            matchesIngredients: sameIngredients,
            portionRatio: sameIngredients
                ? meal.composition!.totalGrams / targetComposition!.totalGrams
                : null,
          ),
        );
      }
    }
    matches.sort((a, b) {
      if (a.matchesIngredients != b.matchesIngredients) {
        return a.matchesIngredients ? -1 : 1;
      }
      final distance = a.distance.compareTo(b.distance);
      if (distance != 0) return distance;
      final date = b.meal.eatenAt.compareTo(a.meal.eatenAt);
      return date != 0 ? date : a.meal.mealId.compareTo(b.meal.mealId);
    });
    return SimilarMealContext(
      asOf: asOf,
      searchStart: start,
      target: target,
      matches: matches.take(maximumMatches).toList(),
    );
  }
}
