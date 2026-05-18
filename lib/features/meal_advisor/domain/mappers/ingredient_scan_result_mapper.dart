import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../data/models/ingredient_scan_result.dart';

extension IngredientScanResultMapper on IngredientScanResult {
  IngredientDraft toIngredientDraft() {
    final nutrition = nutritionPer100g;

    return IngredientDraft.draft(
      name: name ?? '',
      brand: brand,
      carbsPer100g: nutrition?.carbs ?? 0,
      fatPer100g: nutrition?.fat ?? 0,
      fiberPer100g: nutrition?.fiber ?? 0,
      proteinPer100g: nutrition?.protein ?? 0,
      nutritionConfidence: 0.25,
      isReference: false,
    );
  }
}
