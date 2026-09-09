enum MealDecision {
  eatNowBolusLater, // in this version: "eat now, no bolus now; log carbs"
  bolusAndEatNow,
  bolusWaitThenEat,
  bolus,
}

extension MealDecisionX on MealDecision {
  String get status => switch (this) {
    MealDecision.eatNowBolusLater => 'eating-then-bolus',
    MealDecision.bolusAndEatNow => 'bolused-eating',
    MealDecision.bolusWaitThenEat => 'bolused-waiting',
    // TODO: Handle this case.
    MealDecision.bolus => throw UnimplementedError(),
  };

  String get acceptedStatus => switch (this) {
    MealDecision.eatNowBolusLater => 'eating-then-bolus',
    MealDecision.bolusAndEatNow => 'waiting-for-bolus',
    MealDecision.bolusWaitThenEat => 'waiting-for-bolus',
    // TODO: Handle this case.
    MealDecision.bolus => throw UnimplementedError(),
  };
}
