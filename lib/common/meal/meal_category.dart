import '../l10n/language.dart';

enum MealCategory {
  breakfast,
  secondBreakfast,
  lunch,
  snack,
  afternoonSnack,
  dinner;

  static MealCategory? fromStorage(String? value) {
    for (final category in values) {
      if (category.name == value) return category;
    }
    return null;
  }

  String label(AppLocalizations lang) => switch (this) {
    breakfast => lang.mealCategoryBreakfast,
    secondBreakfast => lang.mealCategorySecondBreakfast,
    lunch => lang.mealCategoryLunch,
    snack => lang.mealCategorySnack,
    afternoonSnack => lang.mealCategoryAfternoonSnack,
    dinner => lang.mealCategoryDinner,
  };
}
