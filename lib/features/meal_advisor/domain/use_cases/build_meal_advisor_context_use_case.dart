import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../../../meal_analysis/domain/models/meal_ai_context.dart';
import '../../../meal_analysis/domain/models/similar_meal_context.dart';
import '../../../meal_analysis/domain/use_cases/load_historical_meal_comparisons_use_case.dart';
import '../models/meal_advisor_context.dart';
import '../models/meal_advisor_target.dart';

class BuildMealAdvisorContextUseCase {
  static const maximumComparisons =
      LoadHistoricalMealComparisonsUseCase.maximumComparisons;
  final Future<MealAdvisorTarget> Function(BeforeMealContext) loadTarget;
  final Future<SimilarMealContext> Function(MealAdvisorTarget, DateTime)
  findSimilar;
  final Future<MealAiObservation> Function(int, DateTime) loadHistorical;
  final DateTime Function() now;
  final Duration timeout;
  const BuildMealAdvisorContextUseCase({
    required this.loadTarget,
    required this.findSimilar,
    required this.loadHistorical,
    required this.now,
    this.timeout = const Duration(seconds: 20),
  });
  Future<MealAdvisorContext> call(
    BeforeMealContext before, {
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() == true) {
      return MealAdvisorContext(
        before: before,
        target: null,
        builtAt: now(),
        comparisons: [],
        failures: {'cancelled'},
      );
    }
    final failures = <String>{};
    MealAdvisorTarget? target;
    SimilarMealContext? similar;
    try {
      target = await loadTarget(before).timeout(timeout);
      if (target.mealId != before.mealId) throw StateError('Target mismatch');
    } catch (_) {
      target = null;
      failures.add('target_details');
    }
    if (isCancelled?.call() == true) {
      return MealAdvisorContext(
        before: before,
        target: null,
        builtAt: now(),
        comparisons: [],
        failures: {'cancelled'},
      );
    }
    if (target != null) {
      try {
        similar = await findSimilar(target, before.asOf).timeout(timeout);
      } catch (_) {
        failures.add('similar_search');
      }
    }
    final references = await LoadHistoricalMealComparisonsUseCase(
      load: loadHistorical,
      timeout: timeout,
    )(similar?.matches ?? [], before.asOf, isCancelled: isCancelled);
    failures.addAll(references.failures);
    if (isCancelled?.call() == true) failures.add('cancelled');
    return MealAdvisorContext(
      before: before,
      target: target,
      builtAt: now(),
      comparisons: references.comparisons,
      similarMatchCount: similar?.matches.length,
      failures: failures,
    );
  }
}
