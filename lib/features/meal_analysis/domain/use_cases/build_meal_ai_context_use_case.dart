import '../models/meal_ai_context.dart';
import '../models/similar_meal_context.dart';
import 'load_historical_meal_comparisons_use_case.dart';

class BuildMealAiContextUseCase {
  static const maximumComparisons =
      LoadHistoricalMealComparisonsUseCase.maximumComparisons;
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
    final references = await LoadHistoricalMealComparisonsUseCase(
      load: (id, cutoff) => loadObservation(id, cutoff),
    )(similar?.matches ?? [], current.meal.eatenAt);
    failures.addAll(references.failures);
    return MealAiContext(
      current: current,
      builtAt: now(),
      comparisons: references.comparisons,
      failures: failures,
    );
  }
}
