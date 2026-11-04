import 'dart:math' as math;

import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/nutrition/ingredient_confidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matching assessments retain their value and level', () {
    for (final level in ConfidenceLevel.values) {
      final value = level.toDouble01();
      final combined = combineIngredientConfidence(
        nutritionConfidence: value,
        quantityConfidence: value,
      );
      expect(combined, closeTo(value, 1e-12));
      expect(ConfidenceLevelX.fromDouble01(combined), level);
    }
  });

  test('low and certain combine to medium regardless of input order', () {
    for (final inputs in [(0.25, 0.95), (0.95, 0.25)]) {
      final combined = combineIngredientConfidence(
        nutritionConfidence: inputs.$1,
        quantityConfidence: inputs.$2,
      );
      expect(combined, closeTo(math.sqrt(0.25 * 0.95), 1e-12));
      expect(ConfidenceLevelX.fromDouble01(combined), ConfidenceLevel.medium);
    }
  });

  test('zero confidence stays zero', () {
    expect(
      combineIngredientConfidence(
        nutritionConfidence: 0,
        quantityConfidence: 0.95,
      ),
      0,
    );
  });
}
