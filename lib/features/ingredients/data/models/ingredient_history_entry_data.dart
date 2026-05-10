class IngredientHistoryEntryData {
  final int id;
  final int ingredientId;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double proteinPer100g;
  final double nutritionConfidence;
  final DateTime createdAt;

  const IngredientHistoryEntryData({
    required this.id,
    required this.ingredientId,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.proteinPer100g,
    required this.nutritionConfidence,
    required this.createdAt,
  });
}
