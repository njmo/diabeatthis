import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/models/meal_ingredient_replacement_result.dart';
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

    for (final isReference in [false, true]) {
      test('edits in place with one update (reference: $isReference)', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(mealDraftProvider.notifier);
        final first = _mealIngredient(ingredientId: 11);
        final original = _mealIngredient(ingredientId: 12);
        final middle = original.copyWith(
          ingredient: original.ingredient.copyWith(isReference: isReference),
        );
        final last = _mealIngredient(ingredientId: 13);
        notifier.setMealIngredients([first, middle, last]);
        final updates = <MealDraft>[];
        final subscription = container.listen(mealDraftProvider, (_, next) {
          updates.add(next);
        });
        addTearDown(subscription.close);
        final replacement = middle.copyWith(amount: 2);

        final result = notifier.replaceMealIngredient(middle, replacement);

        expect(result, MealIngredientReplacementResult.replaced);
        expect(container.read(mealDraftProvider).mealIngredients, [
          first,
          replacement,
          last,
        ]);
        expect(updates, hasLength(1));
        expect(updates.single.mealIngredients, [first, replacement, last]);
      });
    }

    final duplicateCandidates = {
      'ingredient ID': _mealIngredient(ingredientId: 12),
      'barcode': _mealIngredient(barcode: '8714800048378'),
      'new ingredient draft': _mealIngredient(),
    };
    for (final entry in duplicateCandidates.entries) {
      test('rejects duplicate by ${entry.key} without changing the draft', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(mealDraftProvider.notifier);
        final original = _mealIngredient(ingredientId: 11);
        notifier.setMealIngredients([original, entry.value]);
        final before = container.read(mealDraftProvider);

        final result = notifier.replaceMealIngredient(
          original,
          entry.value.copyWith(
            amount: 80,
            ingredient: entry.key == 'new ingredient draft'
                ? entry.value.ingredient
                : entry.value.ingredient.copyWith(name: 'Updated product name'),
          ),
        );

        expect(result, MealIngredientReplacementResult.duplicate);
        expect(container.read(mealDraftProvider), same(before));
      });
    }

    test('does not restore an ingredient removed while editing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealDraftProvider.notifier);
      final original = _mealIngredient(ingredientId: 12);
      final remaining = _mealIngredient(ingredientId: 13);
      notifier.setMealIngredients([original, remaining]);
      notifier.removeMealIngredient(original);
      final before = container.read(mealDraftProvider);

      final result = notifier.replaceMealIngredient(
        original,
        original.copyWith(amount: 80),
      );

      expect(result, MealIngredientReplacementResult.notFound);
      expect(container.read(mealDraftProvider), same(before));
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
