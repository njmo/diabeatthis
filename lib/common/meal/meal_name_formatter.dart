import '../l10n/language.dart';
import 'meal_category.dart';

String formatAutomaticMealName(
  AppLocalizations lang,
  List<String> ingredients,
  MealCategory? category,
) {
  final joined = ingredients.join(', ');
  final name = category == null
      ? lang.mealAutomaticName(joined)
      : lang.mealCategorizedName(category.label(lang), joined);
  return limitMealName(name);
}

String limitMealName(String name) =>
    name.length > 120 ? name.substring(0, 120) : name;

String recategorizeMealName(
  AppLocalizations language,
  String name,
  MealCategory category,
) {
  final prefixes = [
    language.mealCategoryNone,
    ...MealCategory.values.map((value) => value.label(language)),
  ];
  for (final prefix in prefixes) {
    if (name.startsWith('$prefix: ')) {
      return limitMealName(
        language.mealCategorizedName(
          category.label(language),
          name.substring(prefix.length + 2),
        ),
      );
    }
  }
  return name;
}
