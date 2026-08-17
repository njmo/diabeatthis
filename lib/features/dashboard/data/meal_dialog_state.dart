import 'utils/meal_advisor.dart';

enum MealDialogStep {
  choose,
  confirm,
  confirmEaten,
  confirmEating,
  confirmBolusedAfterEating,
  waitingForBolus,
}

class MealDialogState {
  final MealDialogStep step;
  final bool skipMeal;
  final double carbsGrams;
  final double extendedCarbsGrams;
  final MealAdvice advice;
  final String? activationBlockedByMealName;

  const MealDialogState({
    required this.step,
    required this.skipMeal,
    required this.advice,
    required this.carbsGrams,
    required this.extendedCarbsGrams,
    required this.activationBlockedByMealName,
  });

  MealDialogState copyWith({
    MealDialogStep? step,
    bool? skipMeal,
    MealAdvice? advice,
    double? carbsGrams,
    double? extendedCarbsGrams,
    String? activationBlockedByMealName,
    bool clearActivationBlock = false,
  }) {
    return MealDialogState(
      step: step ?? this.step,
      skipMeal: skipMeal ?? this.skipMeal,
      advice: advice ?? this.advice,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      extendedCarbsGrams: extendedCarbsGrams ?? this.extendedCarbsGrams,
      activationBlockedByMealName: clearActivationBlock
          ? null
          : activationBlockedByMealName ?? this.activationBlockedByMealName,
    );
  }

  static MealDialogState initial(MealDialogStep step) => MealDialogState(
    step: step,
    skipMeal: false,
    carbsGrams: 0,
    extendedCarbsGrams: 0,
    advice: MealAdvice.empty(),
    activationBlockedByMealName: null,
  );
}
