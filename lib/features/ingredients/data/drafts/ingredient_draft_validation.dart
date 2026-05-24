import 'ingredient_draft.dart';

extension IngredientDraftValidation on IngredientDraft {
  bool get hasEnergyMacros =>
      carbsPer100g > 0 || fatPer100g > 0 || proteinPer100g > 0;
}
