import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WbtExtendedCarbsCalculator', () {
    const calculator = WbtExtendedCarbsCalculator();

    test('does not suggest extended carbs at exactly one WBT', () {
      final suggestion = calculator.calculateFromKcal(100);

      expect(suggestion.wbt, 1);
      expect(suggestion.grams, 0);
      expect(suggestion.shouldSuggest, isFalse);
    });

    test('converts WBT over one into calculator carbs grams', () {
      final suggestion = calculator.calculateFromMacros(
        fatGrams: 20,
        proteinGrams: 10,
      );

      expect(suggestion.kcal, 220);
      expect(suggestion.wbt, 2.2);
      expect(suggestion.grams, 22);
      expect(suggestion.shouldSuggest, isTrue);
    });
  });
}
