import '../../../../core/domain/model/meal.dart';

class IngredientUsageData {
  int mealId;
  String name;
  final MealPurpose purpose;
  String description;
  DateTime plannedAt;
  String status;

  IngredientUsageData({
    required this.mealId,
    required this.name,
    this.purpose = MealPurpose.meal,
    required this.description,
    required this.plannedAt,
    required this.status,
  });
}
