import 'dart:convert';

import 'package:diabeatthis/features/meal_photo/data/meal_photo_prompt.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart'
    show TestPhotoCandidates, TestPhotoClient;

class CountryPhotoClient extends TestPhotoClient {
  MealPhotoInput? received;
  @override
  Future<String> describe(MealPhotoInput input) {
    received = input;
    return super.describe(input);
  }
}

void main() {
  test(
    'country stays independent of app language and survives request localization',
    () async {
      final client = CountryPhotoClient();
      await ProposeMealFromPhotoUseCase(
        client: client,
        candidates: TestPhotoCandidates(),
      )(
        const MealPhotoInput(
          mealPhotoPath: 'meal.jpg',
        ).withResidenceCountry('  Poland  '),
        languageCode: 'en',
      );
      expect(client.received!.residenceCountry, 'Poland');
      expect(client.received!.languageCode, 'en');
      final prompt = const MealPhotoPrompt().build(client.received!);
      final data =
          jsonDecode(prompt.split('INPUT_DATA:\n').last)
              as Map<String, dynamic>;
      expect(data['residence_country'], 'Poland');
      expect(data['app_language_code'], 'en');
      expect(prompt, contains('NOT the confirmed location of the restaurant'));
    },
  );

  test(
    'unknown country stays unknown instead of inferring it from Polish language',
    () {
      final prompt = const MealPhotoPrompt().build(
        const MealPhotoInput(mealPhotoPath: 'meal.jpg', languageCode: 'pl'),
      );
      final data =
          jsonDecode(prompt.split('INPUT_DATA:\n').last)
              as Map<String, dynamic>;
      expect(data['residence_country'], isNull);
    },
  );
}
