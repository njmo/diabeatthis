import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_add_on_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mealStatusAfterAddOn', () {
    test('uses eating-extra for a regular eating add-on', () {
      expect(mealStatusAfterAddOn('eating'), 'eating-extra');
    });

    test('preserves eat-then-bolus flow after an add-on', () {
      expect(mealStatusAfterAddOn('eating-then-bolus'), 'eating-then-bolus');
    });

    test('preserves already bolused eating flow after an add-on', () {
      expect(mealStatusAfterAddOn('bolused-eating'), 'bolused-eating');
    });
  });

  group('buildMealAddOnGuidance', () {
    test('shows only add-on carbs for a regular eating meal', () {
      final guidance = buildMealAddOnGuidance(
        currentMealStatus: 'eating',
        addedCarbs: 12,
        totalCarbsForBolus: null,
      );

      expect(guidance.title, 'Dokładka: +12g węglowodanów');
      expect(guidance.message, contains('Wpisz +12g'));
      expect(guidance.message, isNot(contains('łącznie')));
    });

    test('shows total eaten carbs for eat-then-bolus meal', () {
      final guidance = buildMealAddOnGuidance(
        currentMealStatus: 'eating-then-bolus',
        addedCarbs: 12,
        totalCarbsForBolus: 52,
      );

      expect(guidance.title, 'Do AAPS: 52g węglowodanów');
      expect(guidance.message, contains('Dokładka dodała około 12g'));
      expect(guidance.message, contains('w AAPS wpisz łącznie 52g'));
    });
  });
}
