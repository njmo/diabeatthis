import '../../../../common/async/async_task_pool.dart';
import '../models/meal_ai_context.dart';
import '../models/similar_meal_context.dart';

class BuildMealAiContextUseCase {
  static const maximumComparisons = 3;
  final Future<MealAiObservation> Function(int, DateTime?) loadObservation;
  final Future<SimilarMealContext?> Function(MealAiObservation) loadSimilar;
  final DateTime Function() now;
  const BuildMealAiContextUseCase({
    required this.loadObservation,
    required this.loadSimilar,
    required this.now,
  });

  Future<MealAiContext> call(int mealId) async {
    final current = await loadObservation(mealId, null);
    if (current.meal.mealId != mealId || current.meal.eatenAt.isAfter(now())) {
      throw StateError('Invalid target meal');
    }
    final failures = <String>{};
    SimilarMealContext? similar;
    try {
      similar = await loadSimilar(current);
    } catch (_) {
      failures.add('similar_search');
    }
    final pool = AsyncTaskPool(2);
    final matches = similar?.matches.take(maximumComparisons).toList() ?? [];
    final observations = await Future.wait(
      matches.indexed.map(
        (entry) => pool.run(() async {
          try {
            final observed = await loadObservation(
              entry.$2.meal.mealId,
              current.meal.eatenAt,
            );
            // Never compare outcomes that were not complete before the target meal.
            if (observed.meal.mealId != entry.$2.meal.mealId ||
                !observed.meal.eatenAt.isBefore(current.meal.eatenAt) ||
                observed.outcome == null ||
                !observed.outcome!.isTimeWindowComplete ||
                observed.outcome!.expectedUntil.isAfter(current.meal.eatenAt)) {
              failures.add('comparison_${entry.$1 + 1}');
              return null;
            }
            return MealAiComparison(match: entry.$2, observation: observed);
          } catch (_) {
            failures.add('comparison_${entry.$1 + 1}');
            return null;
          }
        }),
      ),
    );
    return MealAiContext(
      current: current,
      builtAt: now(),
      comparisons: observations.whereType<MealAiComparison>().toList(),
      failures: failures,
    );
  }
}
