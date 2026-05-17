import 'package:diabeatthis/features/ingredients/presentation/utils/reference_ingredient_macro_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reference ingredient macro calculator', () {
    test('splits extended carbs into protein and fat kcal by fat share', () {
      final fatPer100g = referenceFatPer100g(
        extendedCarbsPer100g: 10,
        fatShare: 0.25,
      );
      final proteinPer100g = referenceProteinPer100g(
        extendedCarbsPer100g: 10,
        fatShare: 0.25,
      );

      expect(fatPer100g, closeTo(25 / 9, 0.001));
      expect(proteinPer100g, closeTo(75 / 4, 0.001));
    });

    test('recreates extended carbs from stored fat and protein', () {
      final extendedCarbs = referenceExtendedCarbsPer100g(
        fatPer100g: 5,
        proteinPer100g: 10,
      );

      expect(extendedCarbs, 8.5);
    });

    test('calculates fat share from stored WBT calories', () {
      final fatShare = referenceFatShare(fatPer100g: 5, proteinPer100g: 10);

      expect(fatShare, closeTo(45 / 85, 0.001));
    });
  });
}
