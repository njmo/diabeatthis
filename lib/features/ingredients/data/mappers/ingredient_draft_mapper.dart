import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../data/drafts/ingredient_draft.dart';

extension IngredientDraftMapper on domain.Ingredient {
  IngredientSelection toSelection() {
    return IngredientSelection.existing(
      id: id,
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      proteinPer100g: proteinPer100g,
      fiberPer100g: fiberPer100g,
    );
  }
}
