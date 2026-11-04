import 'package:diabeatthis/features/meals/data/providers/copied_meal_preview_weight_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  test(
    'preview totals sum physical grams for grams, named and recorded portions',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ingredient = mealFlowIngredient(container);
      final named = ingredient.copyWith(
        amount: 2,
        ingredientPortion: ingredient.ingredientPortion.copyWith(
          portion: const PortionSelection.draft(name: 'slice', unitHint: 'g'),
          amount: 35,
        ),
      );
      final recorded = named.copyWith(amount: 3, recordedGramsPerAmount: 20);
      final result = await container.read(
        copiedMealPreviewWeightProvider([ingredient, named, recorded]).future,
      );
      expect(result, 230);
    },
  );

  test('preview omits total weight if a portion mass is unavailable', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ingredient = mealFlowIngredient(container);
    final unknown = ingredient.copyWith(
      amount: 1,
      ingredientPortion: ingredient.ingredientPortion.copyWith(
        portion: const PortionSelection.draft(name: 'slice', unitHint: 'g'),
        amount: 0,
      ),
    );
    expect(
      await container.read(
        copiedMealPreviewWeightProvider([ingredient, unknown]).future,
      ),
      isNull,
    );
  });
}
