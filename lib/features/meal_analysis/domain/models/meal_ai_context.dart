import 'before_meal_context.dart';
import 'meal_ai_facts.dart';
import 'meal_outcome_context.dart';
import 'similar_meal_context.dart';

class MealAiObservation {
  final MealAiFacts meal;
  final BeforeMealContext before;
  final MealOutcomeContext? outcome;
  const MealAiObservation({
    required this.meal,
    required this.before,
    required this.outcome,
  });
}

class MealAiComparison {
  final SimilarMealMatch match;
  final MealAiObservation observation;
  const MealAiComparison({required this.match, required this.observation});
}

class MealAiContext {
  final MealAiObservation current;
  final DateTime builtAt;
  final List<MealAiComparison> comparisons;
  final Set<String> failures;
  MealAiContext({
    required this.current,
    required this.builtAt,
    required List<MealAiComparison> comparisons,
    required Set<String> failures,
  }) : comparisons = List.unmodifiable(comparisons),
       failures = Set.unmodifiable(failures);
}
