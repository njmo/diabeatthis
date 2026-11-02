import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

MealIngredientsDraft mealFlowIngredient(ProviderContainer container) {
  final ingredient = container.read(mealIngredientsDraftProvider);
  return ingredient.copyWith(
    ingredient: ingredient.ingredient.copyWith(
      name: 'Oatmeal',
      iconAssetPath: 'assets/icons/food/prepared_meal.png',
      carbsPer100g: 20,
      fiberPer100g: 3,
      proteinPer100g: 4,
      fatPer100g: 2,
    ),
    ingredientPortion: ingredient.ingredientPortion.copyWith(
      portion: const PortionSelection.empty(),
      amount: 1,
    ),
    amount: 100,
  );
}
