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
  MealDecision.eatNowBolusLater => 'Najpierw jedzenie, potem insulina',
  MealDecision.bolusAndEatNow => 'Insulina i jedzenie bez czekania',
  MealDecision.bolusWaitThenEat => 'Insulina, czekanie, jedzenie',
  MealDecision.bolus => 'Insulina',
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
