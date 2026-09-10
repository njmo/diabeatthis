import '../../../../common/meal/meal_decision.dart';

enum MealAdviceReason {
  lowBeforeMealEffect,
  nearLowWithLowBgOrIob,
  nearLowImmediateMeal,
  highBgNotFalling,
  immediateMeal;

  MealDecision get decision => switch (this) {
    lowBeforeMealEffect ||
    nearLowWithLowBgOrIob => MealDecision.eatNowBolusLater,
    nearLowImmediateMeal || immediateMeal => MealDecision.bolusAndEatNow,
    highBgNotFalling => MealDecision.bolusWaitThenEat,
  };
}
