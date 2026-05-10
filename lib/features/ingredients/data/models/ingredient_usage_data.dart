class IngredientUsageData {
  int mealId;
  String name;
  String description;
  DateTime plannedAt;
  String status;

  IngredientUsageData({
    required this.mealId,
    required this.name,
    required this.description,
    required this.plannedAt,
    required this.status,
  });
}
