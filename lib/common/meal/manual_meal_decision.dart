import '../l10n/language.dart';
import 'meal_decision.dart';

class ManualMealDecision {
  final MealDecision decision;
  final int waitMinutes;

  const ManualMealDecision({
    this.decision = MealDecision.bolusAndEatNow,
    this.waitMinutes = 0,
  });
}

String mealDecisionLabel(MealDecision decision) => switch (decision) {
  MealDecision.eatNowBolusLater => lang.manualMealEatThenInsulin,
  MealDecision.bolusAndEatNow => lang.manualMealInsulinAndEat,
  MealDecision.bolusWaitThenEat => lang.manualMealInsulinWaitEat,
  MealDecision.bolus => lang.manualMealInsulin,
};

MealDecision manualMealDecisionFromHistory(
  Iterable<String> statuses, {
  int selectedWaitMinutes = 0,
}) {
  if (statuses.contains('eating-then-bolus')) {
    return MealDecision.eatNowBolusLater;
  }
  if (statuses.contains('bolused-waiting') ||
      statuses.contains('waited-eating')) {
    return MealDecision.bolusWaitThenEat;
  }
  if (statuses.contains('bolused-eating')) {
    return MealDecision.bolusAndEatNow;
  }
  // Before insulin is recorded, the existing selected wait distinguishes the two pending flows.
  return selectedWaitMinutes > 0
      ? MealDecision.bolusWaitThenEat
      : MealDecision.bolusAndEatNow;
}
