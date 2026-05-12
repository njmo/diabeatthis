import 'package:diabeatthis/features/meal_advisor/data/prompts/ingredient_photo_scan_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ingredientPhotoScanPrompt', () {
    test('defines the expected JSON contract', () {
      expect(ingredientPhotoScanPrompt, contains('"status": "recognized"'));
      expect(ingredientPhotoScanPrompt, contains('"status": "needsRetake"'));
      expect(ingredientPhotoScanPrompt, contains('"nutritionPer100g"'));
      expect(ingredientPhotoScanPrompt, contains('"carbs"'));
      expect(ingredientPhotoScanPrompt, contains('"fat"'));
      expect(ingredientPhotoScanPrompt, contains('"protein"'));
      expect(ingredientPhotoScanPrompt, contains('"fiber"'));
      expect(ingredientPhotoScanPrompt, contains('"portions"'));
      expect(ingredientPhotoScanPrompt, contains('"photo"'));
      expect(
        ingredientPhotoScanPrompt,
        contains('front | nutritionLabel | both'),
      );
    });

    test('requires plain JSON with English keys', () {
      expect(
        ingredientPhotoScanPrompt,
        contains('Return only one JSON object'),
      );
      expect(ingredientPhotoScanPrompt, contains('Do not wrap it in Markdown'));
      expect(ingredientPhotoScanPrompt, contains('Use English JSON keys'));
    });

    test('keeps incomplete recognized scans for app-side review', () {
      expect(
        ingredientPhotoScanPrompt,
        contains('still return\n"recognized" with the fields you can read'),
      );
      expect(
        ingredientPhotoScanPrompt,
        contains('continue with a draft or retry the photos'),
      );
    });
  });
}
