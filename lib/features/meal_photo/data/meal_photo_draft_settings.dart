import '../../../common/meal/meal_category.dart';

class MealPhotoDraftSettings {
  const MealPhotoDraftSettings({
    required this.category,
    required this.plannedAt,
  });
  final MealCategory category;
  final DateTime plannedAt;
}
