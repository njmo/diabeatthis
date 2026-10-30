import 'ingredient_details_data.dart';
import 'ingredient_history_entry_data.dart';

class IngredientNutritionValues {
  const IngredientNutritionValues({
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.protein,
    required this.confidence,
  });

  factory IngredientNutritionValues.current(Ingredient ingredient) =>
      IngredientNutritionValues(
        carbs: ingredient.carbsPer100g,
        fat: ingredient.fatPer100g,
        fiber: ingredient.fiberPer100g,
        protein: ingredient.proteinPer100g,
        confidence: ingredient.nutritionConfidence,
      );

  factory IngredientNutritionValues.history(IngredientHistoryEntryData entry) =>
      IngredientNutritionValues(
        carbs: entry.carbsPer100g,
        fat: entry.fatPer100g,
        fiber: entry.fiberPer100g,
        protein: entry.proteinPer100g,
        confidence: entry.nutritionConfidence,
      );

  final double carbs;
  final double fat;
  final double fiber;
  final double protein;
  final double confidence;

  bool sameMacros(IngredientNutritionValues other) =>
      carbs == other.carbs &&
      fat == other.fat &&
      fiber == other.fiber &&
      protein == other.protein;
}
