import '../l10n/language.dart';

bool isQuickMealName(String name) => name.trimLeft().startsWith('QM:');

String mealDisplayName(String name) {
  if (!isQuickMealName(name)) return name;
  final displayName = name.trimLeft().substring(3).trim();
  return displayName.isEmpty ? lang.mealProgressQuickMeal : displayName;
}
