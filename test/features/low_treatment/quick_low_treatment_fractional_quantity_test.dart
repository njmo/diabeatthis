import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/portion.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/features/low_treatment/data/mappers/quick_low_treatment_item_mapper.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reference in [false, true]) {
    for (final quantity in [0.5, 1.5]) {
      test(
        'fractional quick quantity preserves amounts and macros (reference=$reference, quantity=$quantity)',
        () async {
          final item = QuickLowTreatmentItem(
            id: 1,
            name: 'Banana',
            ingredient: Ingredient(
              id: 1,
              name: 'Banana',
              carbsPer100g: 20,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              isReference: reference,
            ),
            portion: reference
                ? null
                : const Portion(id: 1, name: 'Banana', unitHint: 'piece'),
            amount: 1,
            sortOrder: 1,
            gramsPerPortion: reference ? null : 100,
          );
          final draft = item.toMealIngredientDraft(quantity: quantity);
          expect(draft.amount, quantity);
          expect(item.amount, 1);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final provider = FutureProvider(
            (ref) => calculateMealIngredientsMacronutrients(ref, [draft]),
          );
          final summary = await container.read(provider.future);
          expect(summary.carbsTotal, 20 * quantity);
          expect(summary.netCarbsTotal, 20 * quantity);
          expect(summary.extendedCarbsTotal, 0);
        },
      );
    }
  }

  test(
    'half a gram-based shortcut halves its stored amount without rounding',
    () {
      const juice = QuickLowTreatmentItem(
        id: 2,
        name: 'Juice',
        ingredient: Ingredient(
          id: 2,
          name: 'Juice',
          carbsPer100g: 10,
          fatPer100g: 0,
          fiberPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
        ),
        portion: null,
        amount: 125,
        sortOrder: 2,
        gramsPerPortion: null,
      );
      expect(juice.toMealIngredientDraft(quantity: 0.5).amount, 62.5);
    },
  );
}
