import 'package:diabeatthis/features/meal_photo/data/meal_photo_prompt.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_response_schema.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/services/meal_photo_proposal_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

void main() {
  const parser = MealPhotoProposalParser();
  for (final entry in {
    'low': .25,
    'medium': .5,
    'high': .75,
    'certain': .95,
  }.entries) {
    test(
      'named confidence ${entry.key} maps to existing application level',
      () {
        final row = fixtures.component('sauce', kind: 'proposed_reference')
          ..['recognition_confidence'] = entry.key
          ..['nutrition_confidence'] = entry.key
          ..['quantity_confidence'] = entry.key;
        final item = parser.parse(fixtures.proposal(item: row)).itemized.single;
        expect(item.recognitionConfidence, entry.value);
        expect(item.nutritionConfidence, entry.value);
        expect(item.quantityConfidence, entry.value.clamp(0, .5));
      },
    );
  }
  test(
    'new schema and prompt require four levels while legacy numeric responses remain readable',
    () {
      expect(MealPhotoResponseSchema.confidenceLevel['type'], 'string');
      expect(MealPhotoResponseSchema.confidenceLevel['enum'], [
        'low',
        'medium',
        'high',
        'certain',
      ]);
      final prompt = const MealPhotoPrompt().build(
        const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
      );
      expect(
        prompt,
        contains('never return percentages, decimals or numeric scores'),
      );
      expect(
        parser.parse(fixtures.proposal()).itemized.single.recognitionConfidence,
        .8,
      );
      expect(() => parser.confidence('95%'), throwsFormatException);
      expect(() => parser.confidence('unknown'), throwsFormatException);
    },
  );
}
