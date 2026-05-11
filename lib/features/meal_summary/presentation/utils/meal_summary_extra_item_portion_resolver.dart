import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';

typedef MealSummaryPortionAmountLoader = Future<double?> Function();

Future<MealIngredientsDraft> resolveMealSummaryExtraItemPortionAmount({
  required MealIngredientsDraft item,
  required MealSummaryPortionAmountLoader loadPortionAmount,
}) async {
  if (item.ingredient.isReference || item.ingredientPortion.amount > 0) {
    return item;
  }

  final canResolveExistingPortion = item.ingredientPortion.portion.map(
    draft: (_) => false,
    existing: (_) => true,
    empty: (_) => false,
  );
  if (!canResolveExistingPortion) {
    return item;
  }

  final amount = await loadPortionAmount();
  if (amount == null || amount <= 0) {
    return item;
  }

  return item.copyWith(
    ingredientPortion: item.ingredientPortion.copyWith(amount: amount),
  );
}
