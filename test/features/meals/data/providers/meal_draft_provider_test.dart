import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('MealDraftNotifier', () {
    test('does not add the same existing ingredient twice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);

      final firstAdded = notifier.addMealIngredient(
        _mealIngredient(ingredientId: 12),
      );
      final secondAdded = notifier.addMealIngredient(
        _mealIngredient(ingredientId: 12, amount: 80),
      );

      expect(firstAdded, true);
      expect(secondAdded, false);
      expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    });

    test('does not add the same scanned draft twice by barcode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);

      notifier.addMealIngredient(_mealIngredient(barcode: '8714800048378'));
      notifier.addMealIngredient(
        _mealIngredient(barcode: '8714800048378', amount: 80),
      );

      expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    });

    test('does not add the same new ingredient draft twice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);

      final firstAdded = notifier.addMealIngredient(_mealIngredient());
      final secondAdded = notifier.addMealIngredient(
        _mealIngredient(amount: 80),
      );

      expect(firstAdded, true);
      expect(secondAdded, false);
      expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    });

    test('removes only one matching entry from the list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);
      final ingredient = _mealIngredient(ingredientId: 12);
      notifier.setMealIngredients([ingredient, ingredient]);

      notifier.removeMealIngredient(ingredient);

      expect(container.read(mealDraftProvider).mealIngredients, hasLength(1));
    });
  });
}

MealIngredientsDraft _mealIngredient({
  int? ingredientId,
  String? barcode,
  double amount = 100,
}) {
  return MealIngredientsDraft(
    ingredient: ingredientId == null
        ? IngredientDraft.draft(
            name: 'Bavaria 0,0% Ginger Lime',
            brand: 'Bavaria',
            barcode: barcode,
            carbsPer100g: 7,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 0.8,
            isReference: false,
          )
        : IngredientDraft.existing(
            id: ingredientId,
            name: 'Bavaria 0,0% Ginger Lime',
            brand: 'Bavaria',
            barcode: barcode,
            carbsPer100g: 7,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 0.8,
            isReference: false,
          ),
    ingredientPortion: IngredientPortionDraft(
      portion: PortionSelection.empty(),
      amount: amount,
    ),
    amount: amount,
    quantityConfidence: 0.8,
    entryType: 'planned',
    consumedAmount: 0,
    consumedConfidence: 0,
  );
}
