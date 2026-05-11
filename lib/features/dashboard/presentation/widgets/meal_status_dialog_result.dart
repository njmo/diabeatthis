sealed class MealStatusDialogResult {
  const MealStatusDialogResult();
}

class MealStatusUpdateResult extends MealStatusDialogResult {
  const MealStatusUpdateResult(this.status);

  final String status;
}

class MealStatusAddOnResult extends MealStatusDialogResult {
  const MealStatusAddOnResult(this.choice);

  final MealAddOnChoice choice;
}

enum MealAddOnChoice { oneAndHalfPortion, doublePortion, advanced }

extension MealAddOnChoiceMultiplier on MealAddOnChoice {
  double? get multiplier => switch (this) {
    MealAddOnChoice.oneAndHalfPortion => 1.5,
    MealAddOnChoice.doublePortion => 2.0,
    MealAddOnChoice.advanced => null,
  };
}
