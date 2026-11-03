import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ordinary add flow rejects same ingredient with another portion weight',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);

      MealIngredientsDraft item(double gramsPerPortion) => MealIngredientsDraft(
        ingredient: IngredientDraft.existing(
          id: 17,
          name: 'Bread',
          carbsPer100g: 50,
          fiberPer100g: 0,
          fatPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: const PortionSelection.draft(
            name: 'Slice',
            unitHint: 'piece',
          ),
          amount: gramsPerPortion,
        ),
        amount: 2,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );

      expect(notifier.addMealIngredient(item(40)), isTrue);
      expect(notifier.addMealIngredient(item(30)), isFalse);
      expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    },
  );
}
