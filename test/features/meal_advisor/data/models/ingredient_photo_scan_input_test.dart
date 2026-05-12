import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IngredientPhotoScanInput', () {
    test('requires front and nutrition label photos', () {
      const empty = IngredientPhotoScanInput();
      const frontOnly = IngredientPhotoScanInput(frontPhotoPath: 'front.jpg');
      const complete = IngredientPhotoScanInput(
        frontPhotoPath: 'front.jpg',
        nutritionLabelPhotoPath: 'nutrition.jpg',
      );

      expect(empty.hasRequiredPhotos, isFalse);
      expect(frontOnly.hasRequiredPhotos, isFalse);
      expect(complete.hasRequiredPhotos, isTrue);
    });

    test('updates selected photo path', () {
      final input = const IngredientPhotoScanInput(
        frontPhotoPath: 'front.jpg',
      ).withPhoto(IngredientPhotoScanPhoto.nutritionLabel, 'nutrition.jpg');

      expect(input.frontPhotoPath, 'front.jpg');
      expect(input.nutritionLabelPhotoPath, 'nutrition.jpg');
      expect(input.pathFor(IngredientPhotoScanPhoto.front), 'front.jpg');
      expect(
        input.pathFor(IngredientPhotoScanPhoto.nutritionLabel),
        'nutrition.jpg',
      );
    });
  });
}
