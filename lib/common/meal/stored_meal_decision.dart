import 'manual_meal_decision.dart';
import 'meal_decision.dart';

/// Supports persisted workflow statuses and enum names without inventing a choice.
MealDecision? storedMealDecision(String? value) => switch (value) {
  'eating-then-bolus' || 'eatNowBolusLater' => MealDecision.eatNowBolusLater,
  'bolused-eating' || 'bolusAndEatNow' => MealDecision.bolusAndEatNow,
  'bolused-waiting' || 'bolusWaitThenEat' => MealDecision.bolusWaitThenEat,
  'bolus' => MealDecision.bolus,
  _ => null,
};

String storedMealDecisionLabel(String? value) {
  if (value == 'manual') return 'Decyzja ręczna';
  final decision = storedMealDecision(value);
  return decision == null ? 'Nieznany wynik' : mealDecisionLabel(decision);
}
