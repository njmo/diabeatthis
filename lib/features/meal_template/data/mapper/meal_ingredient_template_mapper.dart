import '../../../meals/data/drafts/meal_draft.dart';
import '../drafts/template_meal_draft.dart';

extension MealIngredientTemplateMapper on MealIngredientsDraft {
  MealTemplateIngredientsDraft toTemplateIngredient() {
    return MealTemplateIngredientsDraft(
      ingredient: ingredient,
      ingredientPortion: ingredientPortion,
      defaultAmount: amount,
      quantityConfidence: quantityConfidence,
      isOptional: false,
      prepMethod: '',
      notes: '',
    );
  }
}
