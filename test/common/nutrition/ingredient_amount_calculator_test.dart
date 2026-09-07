import 'package:diabeatthis/common/nutrition/ingredient_amount_calculator.dart';
import 'package:diabeatthis/common/nutrition/ingredient_amount_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gram amounts ignore portion weights', () {
    final multiplier = resolveIngredientGramsPerPortion(
      kind: IngredientAmountKind.grams,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 1);
    expect(
      calculateIngredientTotalGrams(
        amount: 150,
        kind: IngredientAmountKind.grams,
        gramsPerPortion: multiplier,
      ),
      150,
    );
  });

  test('reference portions retain the existing 100 g multiplier', () {
    final multiplier = resolveIngredientGramsPerPortion(
      kind: IngredientAmountKind.referencePortion,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 100);
    expect(
      calculateIngredientTotalGrams(
        amount: 0.5,
        kind: IngredientAmountKind.referencePortion,
        gramsPerPortion: multiplier,
      ),
      50,
    );
  });

  test('explicit portion weight takes precedence over stored weight', () {
    final multiplier = resolveIngredientGramsPerPortion(
      kind: IngredientAmountKind.portion,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 35);
    expect(
      calculateIngredientTotalGrams(
        amount: 2,
        kind: IngredientAmountKind.portion,
        gramsPerPortion: multiplier,
      ),
      70,
    );
  });

  test('uses stored weight when portion weight is unspecified', () {
    final multiplier = resolveIngredientGramsPerPortion(
      kind: IngredientAmountKind.portion,
      portionGrams: 0,
      storedGramsPerPortion: 35,
    );
    expect(multiplier, 35);
    expect(
      calculateIngredientTotalGrams(
        amount: 1.5,
        kind: IngredientAmountKind.portion,
        gramsPerPortion: multiplier,
      ),
      52.5,
    );
  });

  for (final storedWeight in <double?>[null, 0, -1]) {
    test(
      'does not invent total weight for missing or invalid portion weight ($storedWeight)',
      () {
        final multiplier = resolveIngredientGramsPerPortion(
          kind: IngredientAmountKind.portion,
          portionGrams: 0,
          storedGramsPerPortion: storedWeight,
        );
        expect(
          calculateIngredientTotalGrams(
            amount: 2,
            kind: IngredientAmountKind.portion,
            gramsPerPortion: multiplier,
          ),
          isNull,
        );
        expect(
          calculateIngredientTotalGrams(
            amount: 150,
            kind: IngredientAmountKind.grams,
            gramsPerPortion: multiplier,
          ),
          150,
        );
      },
    );
  }

  test('preserves fractional amounts without rounding', () {
    expect(
      calculateIngredientTotalGrams(
        amount: 0.25,
        kind: IngredientAmountKind.portion,
        gramsPerPortion: 35,
      ),
      8.75,
    );
  });
}
