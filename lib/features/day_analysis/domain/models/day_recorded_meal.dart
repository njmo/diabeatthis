import '../../../../common/meal/meal_completion_decision.dart';

class DayRecordedMeal {
  final bool requiresCompletion;
  final int id;
  final String name;
  final DateTime eatenAt;
  final MealCompletionDecision? completionDecision;

  const DayRecordedMeal({
    this.requiresCompletion = false,
    required this.id,
    required this.name,
    required this.eatenAt,
    this.completionDecision,
  });
}
