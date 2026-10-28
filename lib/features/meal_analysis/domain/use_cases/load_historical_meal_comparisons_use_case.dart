import '../../../../common/async/async_task_pool.dart';
import '../models/meal_ai_context.dart';
import '../models/similar_meal_context.dart';

typedef HistoricalMealComparisons = ({
  List<MealAiComparison> comparisons,
  Set<String> failures,
});

class LoadHistoricalMealComparisonsUseCase {
  static const maximumComparisons = 3;
  final Future<MealAiObservation> Function(int, DateTime) load;
  final Duration timeout;
  const LoadHistoricalMealComparisonsUseCase({
    required this.load,
    this.timeout = const Duration(seconds: 20),
  });
  Future<HistoricalMealComparisons> call(
    List<SimilarMealMatch> matches,
    DateTime cutoff, {
    bool Function()? isCancelled,
  }) async {
    final failures = <String>{};
    final pool = AsyncTaskPool(2);
    final results = await Future.wait(
      matches
          .take(maximumComparisons)
          .indexed
          .map(
            (entry) => pool.run(() async {
              if (isCancelled?.call() == true) {
                failures.add('cancelled');
                return null;
              }
              try {
                final observation = await load(
                  entry.$2.meal.mealId,
                  cutoff,
                ).timeout(timeout);
                if (isCancelled?.call() == true) {
                  failures.add('cancelled');
                  return null;
                }
                final outcome = observation.outcome;
                if (observation.meal.mealId != entry.$2.meal.mealId ||
                    !observation.meal.eatenAt.isBefore(cutoff) ||
                    outcome == null ||
                    !outcome.isTimeWindowComplete ||
                    outcome.expectedUntil.isAfter(cutoff) ||
                    outcome.observedUntil.isAfter(cutoff)) {
                  throw StateError('Incomplete or future reference');
                }
                return MealAiComparison(
                  match: entry.$2,
                  observation: observation,
                );
              } catch (_) {
                failures.add('comparison_${entry.$1 + 1}');
                return null;
              }
            }),
          ),
    );
    return (
      comparisons: List<MealAiComparison>.unmodifiable(
        results.whereType<MealAiComparison>(),
      ),
      failures: Set<String>.unmodifiable(failures),
    );
  }
}
