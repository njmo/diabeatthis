import 'package:diabeatthis/features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_llm_meal_photo_recognition_client_test.dart';

void main() {
  test('plate alone and whitespace-only optional composition are accepted', () {
    expect(
      () => const MealPhotoInput(mealPhotoPath: 'plate.jpg').validate(),
      returnsNormally,
    );
    expect(
      () => const MealPhotoInput(
        mealPhotoPath: 'plate.jpg',
        description: ' \n\t ',
      ).validate(),
      returnsNormally,
    );
  });
  test(
    'optional composition text and menu photo are accepted independently',
    () {
      expect(
        () => const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Bigos with sausage',
        ).validate(),
        returnsNormally,
      );
      expect(
        () => const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          menuPhotoPath: 'menu.jpg',
        ).validate(),
        returnsNormally,
      );
      const both = MealPhotoInput(
        mealPhotoPath: 'plate.jpg',
        menuPhotoPath: 'menu.jpg',
        description: 'Potatoes with cheese',
      );
      expect(both.validate, returnsNormally);
      expect(both.imagePaths, ['plate.jpg', 'menu.jpg']);
    },
  );
  test(
    'composition evidence does not bypass plate path, menu path or text length validation',
    () {
      expect(
        () => const MealPhotoInput(
          mealPhotoPath: ' ',
          description: 'Potatoes',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes',
          menuPhotoPath: ' ',
        ).validate(),
        throwsArgumentError,
      );
      expect(
        () => MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'x' * 4000,
        ).validate(),
        returnsNormally,
      );
      expect(
        () => MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          menuPhotoPath: 'menu.jpg',
          description: 'x' * 4001,
        ).validate(),
        throwsArgumentError,
      );
    },
  );
  test(
    'the LLM adapter sends plate-only requests to the configured model',
    () async {
      final llm = RecordingPhotoLlm();
      final client = LocalLlmMealPhotoRecognitionClient(llm);
      const input = MealPhotoInput(mealPhotoPath: 'plate.jpg');
      expect(await client.describe(input), 'response');
      expect(await client.resolve(input, 'description', {}), 'response');
      expect(llm.requests, hasLength(2));
      for (final request in llm.requests) {
        expect(request.imagePaths, ['plate.jpg']);
      }
    },
  );
}
