enum MealDialogStep { choose, details, confirm }

class MealDialogState {
  final MealDialogStep step;
  final bool skipMeal;
  final String mealState;
  final double carbsGrams;
  final double extendedCarbsGrams;
  final String waitHint;

  const MealDialogState({
    required this.step,
    required this.skipMeal,
    required this.mealState,
    required this.carbsGrams,
    required this.extendedCarbsGrams,
    required this.waitHint,
  });

  MealDialogState copyWith({
    MealDialogStep? step,
    bool? skipMeal,
    String? mealState,
    double? carbsGrams,
    double? extendedCarbsGrams,
    String? waitHint,
  }) {
    return MealDialogState(
      step: step ?? this.step,
      skipMeal: skipMeal ?? this.skipMeal,
      mealState: mealState ?? this.mealState,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      waitHint: waitHint ?? this.waitHint,
      extendedCarbsGrams: extendedCarbsGrams ?? this.extendedCarbsGrams,
    );
  }

  static MealDialogState initial() => const MealDialogState(
    step: MealDialogStep.choose,
    skipMeal: false,
    mealState: "Przed posiłkiem",
    carbsGrams: 0,
    extendedCarbsGrams: 0,
    waitHint: "",
  );
}