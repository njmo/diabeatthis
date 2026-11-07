import 'package:diabeatthis/common/planning/family_meal_copy_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'copy uses recorded grams and drops execution state and identifiers',
    () {
      final source = FamilyMealCopySource([
        {
          'kind': 'meals',
          'id': '4',
          'payload': {
            'id': 4,
            'name': 'Lunch',
            'purpose': 'meal',
            'planned_at': 1,
          },
        },
        {
          'kind': 'ingredients',
          'id': '7',
          'payload': {
            'id': 7,
            'name': 'Bread',
            'carbs_per_100g': 40.0,
            'fat_per_100g': 1.0,
            'fiber_per_100g': 0.0,
            'protein_per_100g': 3.0,
            'is_reference': 0,
          },
        },
        {
          'kind': 'mealIngredients',
          'id': '9',
          'payload': {
            'meal_id': 4,
            'ingredient_id': 7,
            'amount': 2.0,
            'portion_id': 8,
            'grams_per_portion_used': 35.0,
            'consumed_amount': 1.0,
            'entry_type': 'eaten',
          },
        },
      ]);
      expect(source.search('lunch').single.id, 4);
      final copied = source.ingredients(4).single;
      expect(copied.amount * copied.recordedGramsPerAmount!, 70);
      expect(copied.mealIngredientId, isNull);
      expect(copied.entryType, 'planned');
      expect(copied.consumedAmount, isNull);
      expect(copied.consumedConfidence, isNull);
    },
  );
  test('missing historical portion conversion is never guessed', () {
    const source = FamilyMealCopySource([
      {
        'kind': 'ingredients',
        'id': '7',
        'payload': {'id': 7, 'name': 'Bread', 'is_reference': 0},
      },
      {
        'kind': 'mealIngredients',
        'id': '9',
        'payload': {
          'meal_id': 4,
          'ingredient_id': 7,
          'amount': 2.0,
          'portion_id': 8,
        },
      },
    ]);
    expect(() => source.ingredients(4), throwsStateError);
  });
}
