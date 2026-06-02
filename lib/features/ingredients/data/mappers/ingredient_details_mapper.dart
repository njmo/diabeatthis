import '../drafts/ingredient_draft.dart';
import '../models/ingredient_details_data.dart' as details;

extension IngredientDetailsDraftMapper on details.Ingredient {
  IngredientDraft toDraft() {
    return IngredientDraft.existing(
      id: id,
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      proteinPer100g: proteinPer100g,
      nutritionConfidence: nutritionConfidence,
      isReference: isReference,
      carbsLabelMode: carbsLabelMode,
      netKcalPer100g: netKcalPer100g,
      kcalPer100g: kcalPer100g,
      wbtKcalPer100g: wbtKcalPer100g,
      ig: ig,
      preparation: preparation,
      brand: brand,
    );
  }
}
