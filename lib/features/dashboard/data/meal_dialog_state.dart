import '../../meal_analysis/domain/models/before_meal_context.dart';
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
  final bool isPreparingAdvice;
  final bool isAiAssisted;
  final bool preparationFailed;
  final BeforeMealContext? beforeMealContext;
  final MealDialogStep step;
  final bool skipMeal;
  final double carbsGrams;
  final double extendedCarbsGrams;
  final MealAdvice advice;
  final String? activationBlockedByMealName;

  const MealDialogState({
    this.isPreparingAdvice = false,
    this.isAiAssisted = false,
    this.preparationFailed = false,
    this.beforeMealContext,
    required this.step,
    required this.skipMeal,
    required this.advice,
    required this.carbsGrams,
    required this.extendedCarbsGrams,
    required this.activationBlockedByMealName,
  });

  MealDialogState copyWith({
    bool? isPreparingAdvice,
    bool? isAiAssisted,
    bool? preparationFailed,
    BeforeMealContext? beforeMealContext,
    bool clearBeforeMealContext = false,
    MealDialogStep? step,
    bool? skipMeal,
    MealAdvice? advice,
    double? carbsGrams,
    double? extendedCarbsGrams,
    String? activationBlockedByMealName,
    bool clearActivationBlock = false,
  }) {
    return MealDialogState(
      isPreparingAdvice: isPreparingAdvice ?? this.isPreparingAdvice,
      isAiAssisted: isAiAssisted ?? this.isAiAssisted,
      preparationFailed: preparationFailed ?? this.preparationFailed,
      beforeMealContext: clearBeforeMealContext
          ? null
          : beforeMealContext ?? this.beforeMealContext,
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
