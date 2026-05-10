import 'ingredient_details_data.dart';

class IngredientEditDraft {
  final int ingredientId;
  final String name;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double proteinPer100g;
  final double nutritionConfidence;

  const IngredientEditDraft({
    required this.ingredientId,
    required this.name,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.proteinPer100g,
    required this.nutritionConfidence,
  });

  factory IngredientEditDraft.fromIngredient(Ingredient ingredient) {
    return IngredientEditDraft(
      ingredientId: ingredient.id,
      name: ingredient.name,
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      nutritionConfidence: ingredient.nutritionConfidence,
    );
  }

  IngredientEditDraft copyWith({
    String? name,
    double? carbsPer100g,
    double? fatPer100g,
    double? fiberPer100g,
    double? proteinPer100g,
    double? nutritionConfidence,
  }) {
    return IngredientEditDraft(
      ingredientId: ingredientId,
      name: name ?? this.name,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fiberPer100g: fiberPer100g ?? this.fiberPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      nutritionConfidence: nutritionConfidence ?? this.nutritionConfidence,
    );
  }
}
