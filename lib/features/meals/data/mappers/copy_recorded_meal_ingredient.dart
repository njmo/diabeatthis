import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../drafts/meal_draft.dart';

/// A copied meal is a new plan. Preserve its reviewed mass without binding it
/// to a mutable portion mapping or the original consumption row.
MealIngredientsDraft copyRecordedMealIngredient(MealIngredientsDraft item) {
  if (item.mealIngredientId == null) return item;
  if (item.ingredient.isReference) {
    return item.copyWith(mealIngredientId: null, recordedGramsPerAmount: null);
  }
  final factor =
      item.recordedGramsPerAmount ??
      item.ingredientPortion.portion.map<double>(
        empty: (_) => 1.0,
        existing: (_) => item.ingredientPortion.amount,
        draft: (_) => item.ingredientPortion.amount,
      );
  if (!factor.isFinite || factor <= 0) {
    throw StateError('The recorded meal portion conversion is unavailable');
  }
  return item.copyWith(
    mealIngredientId: null,
    recordedGramsPerAmount: null,
    ingredientPortion: IngredientPortionDraft(
      portion: const PortionSelection.empty(),
      amount: 1,
    ),
    amount: item.amount * factor,
    consumedAmount: item.consumedAmount == null
        ? null
        : item.consumedAmount! * factor,
  );
}
