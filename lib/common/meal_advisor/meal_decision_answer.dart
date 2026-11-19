import '../meal/meal_decision.dart';

enum MealDecisionAnswer {
  insulinThenWait,
  insulinAndEat,
  eatThenInsulin,
  deferMeal;

  MealDecision? get decision => switch (this) {
    insulinThenWait => MealDecision.bolusWaitThenEat,
    insulinAndEat => MealDecision.bolusAndEatNow,
    eatThenInsulin => MealDecision.eatNowBolusLater,
    deferMeal => null,
  };
  bool get requiresMinutes => this == insulinThenWait || this == deferMeal;
}
