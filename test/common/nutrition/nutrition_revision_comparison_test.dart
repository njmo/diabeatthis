import 'package:diabeatthis/common/nutrition/nutrition_revision_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NutritionRevisionComparison revision({
    bool unavailable = false,
    double confidence = .9,
  }) => NutritionRevisionComparison(
    ingredientId: 1,
    name: 'Rice',
    grams: 200,
    recordedPer100g: const {'net_carbs_g': 20},
    currentPer100g: const {'net_carbs_g': 24},
    recordedConfidence: .4,
    currentConfidence: confidence,
    historicalUnavailable: unavailable,
  );
  test('comparison preserves recorded values and uses the same quantity', () {
    final facts = revision().toJson();
    expect(facts['net_carbs_difference_for_recorded_quantity_g'], 8);
    expect(facts['recorded_per_100g'], {'net_carbs_g': 20});
    expect(facts['confidence_increased'], true);
    expect(facts['change_basis'], 'unknown');
    expect(facts['quantity_confidence_not_reassessed'], true);
  });
  test(
    'missing history cannot imply improved confidence or historical macros',
    () {
      final facts = revision(unavailable: true).toJson();
      expect(facts['recorded_per_100g'], isNull);
      expect(facts['recorded_nutrition_confidence'], isNull);
      expect(facts['confidence_increased'], isNull);
      expect(facts['net_carbs_difference_for_recorded_quantity_g'], isNull);
    },
  );
  test('lower confidence is not described as refinement', () {
    expect(revision(confidence: .2).confidenceIncreased, false);
  });
}
