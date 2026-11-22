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

  Map<String, Object?>? remoteResponse(int? minutes, String message) {
    final note = message.trim();
    if (note.length > 240 ||
        (requiresMinutes &&
            (minutes == null || minutes < 1 || minutes > 180))) {
      return null;
    }
    return {
      'type': name,
      'minutes': requiresMinutes ? minutes : null,
      'message': note,
      'targetSuggestion': null,
    };
  }
}
