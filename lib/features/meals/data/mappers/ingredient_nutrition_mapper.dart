import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/drift/database_impl.dart';
import '../../domain/models/ingredient_nutrition_data.dart';

/// Resolves recorded nutrition without presentation labels or meal detail DTOs.
class IngredientNutritionMapper {
  const IngredientNutritionMapper();

  DateTime date(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds);

  ({IngredientNutritionData nutrition, bool historicalUnavailable}) at({
    required IngredientData ingredient,
    required List<IngredientStatusHistoryData> history,
    required DateTime reference,
  }) {
    final sorted = history.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    IngredientStatusHistoryData? selected;
    for (final entry in sorted) {
      if (date(entry.createdAt).isAfter(reference)) {
        break;
      }
      selected = entry;
    }

    if (selected != null) {
      return (
        nutrition: IngredientNutritionData(
          carbsPer100g: selected.carbsPer100g,
          fatPer100g: selected.fatPer100g,
          fiberPer100g: selected.fiberPer100g,
          proteinPer100g: selected.proteinPer100g,
          carbsLabelMode: CarbsLabelModeX.fromStorage(
            ingredient.carbsLabelMode,
          ),
          nutritionConfidence: selected.nutritionConfidence,
          effectiveAt: date(selected.createdAt),
        ),
        historicalUnavailable: false,
      );
    }

    final currentNutrition = current(ingredient);
    final changedAfterReference = history.any(
      (entry) => date(entry.createdAt).isAfter(reference),
    );
    return (
      nutrition: currentNutrition,
      historicalUnavailable:
          changedAfterReference &&
          date(ingredient.updatedAt).isAfter(reference),
    );
  }

  IngredientNutritionData current(IngredientData ingredient) {
    return IngredientNutritionData(
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      carbsLabelMode: CarbsLabelModeX.fromStorage(ingredient.carbsLabelMode),
      nutritionConfidence: ingredient.nutritionConfidence,
      effectiveAt: date(ingredient.updatedAt),
    );
  }
}
