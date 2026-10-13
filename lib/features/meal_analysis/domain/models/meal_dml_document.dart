class MealDmlDocument {
  static const version = 1;
  final int mealId;
  final String text;
  final Set<String> evidenceIds;
  MealDmlDocument({
    required this.mealId,
    required this.text,
    required Set<String> evidenceIds,
  }) : evidenceIds = Set.unmodifiable(evidenceIds);
}
