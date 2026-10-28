import '../../../../common/meal/meal_decision.dart';

/// Application-owned limits. The model cannot choose or widen these limits.
/// No clinical defaults: a future integration must explicitly supply its policy.
class MealAdvisorSuggestionPolicy {
  static const supportedActions = {
    MealDecision.eatNowBolusLater,
    MealDecision.bolusAndEatNow,
    MealDecision.bolusWaitThenEat,
  };
  final int maximumWaitMinutes;
  final Duration maximumContextAge;
  final Set<MealDecision> allowedActions;

  MealAdvisorSuggestionPolicy({
    required this.maximumWaitMinutes,
    required this.maximumContextAge,
    required Set<MealDecision> allowedActions,
  }) : allowedActions = Set.unmodifiable(allowedActions) {
    if (maximumWaitMinutes < 1 ||
        maximumContextAge <= Duration.zero ||
        allowedActions.isEmpty ||
        !supportedActions.containsAll(allowedActions)) {
      throw ArgumentError('Invalid advisor suggestion policy');
    }
  }
}
