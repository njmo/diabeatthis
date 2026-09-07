import 'package:diabeatthis/common/nutrition/ingredient_amount_calculator.dart';
import 'package:diabeatthis/common/nutrition/ingredient_amount_kind.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/presentation/utils/meal_ingredient_portion_formatters.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final isReference in [false, true]) {
    for (final example in [
      (
        name: 'grams',
        portion: const PortionSelection.empty(),
        hasPortion: false,
      ),
      (
        name: 'new portion',
        portion: const PortionSelection.draft(name: 'kromka', unitHint: 'g'),
        hasPortion: true,
      ),
      (
        name: 'existing portion',
        portion: const PortionSelection.existing(
          id: 1,
          name: 'kromka',
          unitHint: 'g',
        ),
        hasPortion: true,
      ),
    ]) {
      test(
        'preserves editor conversion for ${example.name}, reference: $isReference',
        () {
          final draft = MealIngredientsDraft(
            ingredient: IngredientDraft.draft(
              name: 'Test ingredient',
              carbsPer100g: 20,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 0.75,
              isReference: isReference,
            ),
            ingredientPortion: IngredientPortionDraft(
              portion: example.portion,
              amount: 35,
            ),
            amount: 2,
            quantityConfidence: 0.75,
            entryType: 'planned',
            consumedAmount: null,
            consumedConfidence: null,
          );
          final expectedKind = isReference
              ? IngredientAmountKind.referencePortion
              : example.hasPortion
              ? IngredientAmountKind.portion
              : IngredientAmountKind.grams;
          expect(draft.amountKind, expectedKind);
          // The editor keeps the 100 g convention even for legacy reference entries with a portion.
          expect(
            resolveIngredientGramsPerPortion(
              kind: draft.amountKind,
              portionGrams: 35,
            ),
            isReference
                ? 100
                : example.hasPortion
                ? 35
                : 1,
          );
        },
      );
    }
  }
}
