import 'package:diabeatthis/common/nutrition/ingredient_amount_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gram amounts ignore portion weights', () {
    final multiplier = resolveIngredientGramsPerPortion(
      usesGramAmount: true,
      isReference: false,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 1);
    expect(
      calculateIngredientTotalGrams(
        amount: 150,
        usesGramAmount: true,
        gramsPerPortion: multiplier,
      ),
      150,
    );
  });

  test('reference portions retain the existing 100 g multiplier', () {
    final multiplier = resolveIngredientGramsPerPortion(
      usesGramAmount: false,
      isReference: true,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 100);
    expect(
      calculateIngredientTotalGrams(
        amount: 0.5,
        usesGramAmount: false,
        gramsPerPortion: multiplier,
      ),
      50,
    );
  });

  test('explicit portion weight takes precedence over stored weight', () {
    final multiplier = resolveIngredientGramsPerPortion(
      usesGramAmount: false,
      isReference: false,
      portionGrams: 35,
      storedGramsPerPortion: 40,
    );
    expect(multiplier, 35);
    expect(
      calculateIngredientTotalGrams(
        amount: 2,
        usesGramAmount: false,
        gramsPerPortion: multiplier,
      ),
      70,
    );
  });

  test('uses stored weight when portion weight is unspecified', () {
    final multiplier = resolveIngredientGramsPerPortion(
      usesGramAmount: false,
      isReference: false,
      portionGrams: 0,
      storedGramsPerPortion: 35,
    );
    expect(multiplier, 35);
    expect(
      calculateIngredientTotalGrams(
        amount: 1.5,
        usesGramAmount: false,
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
          usesGramAmount: false,
          isReference: false,
          portionGrams: 0,
          storedGramsPerPortion: storedWeight,
        );
        expect(
          calculateIngredientTotalGrams(
            amount: 2,
            usesGramAmount: false,
            gramsPerPortion: multiplier,
          ),
          isNull,
        );
        expect(
          calculateIngredientTotalGrams(
            amount: 150,
            usesGramAmount: true,
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
        usesGramAmount: false,
        gramsPerPortion: 35,
      ),
      8.75,
    );
  });
}
