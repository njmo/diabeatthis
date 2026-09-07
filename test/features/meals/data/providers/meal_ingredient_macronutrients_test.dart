import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/mappers/portion_draft_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test(
    'sums grams, portions and reference portions without changing rounding',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        macroIngredient(amount: 150),
        macroIngredient(
          amount: 2,
          portion: const PortionSelection.draft(name: 'slice', unitHint: 'g'),
          portionGrams: 35,
        ),
        macroIngredient(amount: 0.5, isReference: true, fiber: 0),
      ]);

      final macros = await container.read(
        calculatedMacronutrientsProvider.future,
      );

      expect(
        macros,
        const Macronutrients(
          carbsTotal: 54,
          fatTotal: 27,
          fiberTotal: 5,
          proteinTotal: 15,
          netCarbsTotal: 54,
        ),
      );
    },
  );

  for (final storedGrams in <double?>[35, null]) {
    test(
      'loads stored portion weight with zero fallback ($storedGrams)',
      () async {
        final ingredient = macroIngredient(
          amount: 2,
          portion: const PortionSelection.existing(
            id: 1,
            name: 'slice',
            unitHint: 'g',
          ),
        );
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            getAmountForPortionIngredientProvider(
              ingredient.ingredient.toDomain(),
              ingredient.ingredientPortion.portion.toDomain(),
            ).overrideWith((_) async {
              reads++;
              return storedGrams;
            }),
          ],
        );
        addTearDown(container.dispose);
        container.read(mealDraftProvider.notifier).setMealIngredients([
          ingredient,
        ]);

        final macros = await container.read(
          calculatedMacronutrientsProvider.future,
        );

        expect(reads, 1);
        expect(macros.carbsTotal, storedGrams == null ? 0 : 14);
        expect(macros.fatTotal, storedGrams == null ? 0 : 7);
        expect(macros.proteinTotal, storedGrams == null ? 0 : 4);
        expect(macros.fiberTotal, storedGrams == null ? 0 : 2);
      },
    );
  }

  test(
    'does not fetch stored weight when the draft already contains it',
    () async {
      final ingredient = macroIngredient(
        amount: 2,
        portion: const PortionSelection.existing(
          id: 1,
          name: 'slice',
          unitHint: 'g',
        ),
        portionGrams: 35,
      );
      final container = ProviderContainer(
        overrides: [
          getAmountForPortionIngredientProvider(
            ingredient.ingredient.toDomain(),
            ingredient.ingredientPortion.portion.toDomain(),
          ).overrideWith((_) => throw StateError('Unexpected weight lookup')),
        ],
      );
      addTearDown(container.dispose);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        ingredient,
      ]);

      expect(
        (await container.read(
          calculatedMacronutrientsProvider.future,
        )).carbsTotal,
        14,
      );
    },
  );

  test('rounds each ingredient before adding it to the meal total', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(mealDraftProvider.notifier).setMealIngredients([
      macroIngredient(amount: 2),
      macroIngredient(amount: 2),
    ]);

    final macros = await container.read(
      calculatedMacronutrientsProvider.future,
    );

    expect(macros.carbsTotal, 2);
    expect(macros.netCarbsTotal, 2);
  });

  test('retains explicit portion weight on legacy reference entries', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(mealDraftProvider.notifier).setMealIngredients([
      macroIngredient(
        amount: 2,
        isReference: true,
        portion: const PortionSelection.draft(name: 'portion', unitHint: 'g'),
        portionGrams: 30,
      ),
    ]);

    expect(
      (await container.read(
        calculatedMacronutrientsProvider.future,
      )).carbsTotal,
      12,
    );
  });

  test(
    'keeps legacy negative weights unchanged without fetching a stored weight',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        macroIngredient(
          amount: 2,
          portion: const PortionSelection.draft(name: 'portion', unitHint: 'g'),
          portionGrams: -35,
        ),
      ]);

      expect(
        (await container.read(
          calculatedMacronutrientsProvider.future,
        )).carbsTotal,
        -14,
      );
    },
  );
}

MealIngredientsDraft macroIngredient({
  required double amount,
  bool isReference = false,
  double fiber = 2,
  PortionSelection portion = const PortionSelection.empty(),
  double portionGrams = 0,
}) {
  return MealIngredientsDraft(
    ingredient: IngredientDraft.existing(
      id: 1,
      name: 'Test ingredient',
      carbsPer100g: 20,
      fatPer100g: 10,
      fiberPer100g: fiber,
      proteinPer100g: 5,
      nutritionConfidence: 0.75,
      isReference: isReference,
    ),
    ingredientPortion: IngredientPortionDraft(
      portion: portion,
      amount: portionGrams,
    ),
    amount: amount,
    quantityConfidence: 0.75,
    entryType: 'planned',
    consumedAmount: null,
    consumedConfidence: null,
  );
}
