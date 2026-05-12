import 'package:diabeatthis/features/meal_advisor/data/prompts/ingredient_photo_search_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ingredientPhotoSearchPrompt', () {
    test('defines the expected search JSON contract', () {
      expect(ingredientPhotoSearchPrompt, contains('"names"'));
      expect(ingredientPhotoSearchPrompt, contains('"brand"'));
      expect(ingredientPhotoSearchPrompt, contains('Return at most 5 names'));
      expect(
        ingredientPhotoSearchPrompt,
        contains('Return product and brand names in lowercase'),
      );
    });
  });
}
