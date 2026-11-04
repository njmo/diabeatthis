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
    double? confidenceOverride,
  }) {
    if (reference.isBefore(date(ingredient.createdAt))) {
      return (
        nutrition: current(ingredient, confidenceOverride: confidenceOverride),
        historicalUnavailable: true,
      );
    }
    // History contains the state BEFORE each edit. The first later edit
    // therefore holds the values that applied at the requested instant.
    final sorted = history.toList()
      ..sort((a, b) {
        final time = a.createdAt.compareTo(b.createdAt);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    IngredientStatusHistoryData? selected;
    for (final entry in sorted) {
      if (date(entry.createdAt).isAfter(reference)) {
        selected = entry;
        break;
      }
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
          nutritionConfidence:
              confidenceOverride ?? selected.nutritionConfidence,
          effectiveAt:
              null, // The edit timestamp ends this state; it does not start it.
        ),
        historicalUnavailable: false,
      );
    }

    final currentNutrition = current(
      ingredient,
      confidenceOverride: confidenceOverride,
    );
    return (nutrition: currentNutrition, historicalUnavailable: false);
  }

  IngredientNutritionData current(
    IngredientData ingredient, {
    double? confidenceOverride,
  }) {
    return IngredientNutritionData(
      carbsPer100g: ingredient.carbsPer100g,
      fatPer100g: ingredient.fatPer100g,
      fiberPer100g: ingredient.fiberPer100g,
      proteinPer100g: ingredient.proteinPer100g,
      carbsLabelMode: CarbsLabelModeX.fromStorage(ingredient.carbsLabelMode),
      nutritionConfidence: confidenceOverride ?? ingredient.nutritionConfidence,
      effectiveAt: date(ingredient.updatedAt),
    );
  }
}
