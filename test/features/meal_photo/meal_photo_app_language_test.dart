import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_llm_meal_photo_recognition_client_test.dart';
import 'meal_photo_clarification_test.dart';
import 'meal_photo_proposal_test.dart' as fixtures;

class LanguageRecordingPhotoLlm extends RecordingPhotoLlm {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    await super.generate(request);
    return LocalLlmResponse(text: fixtures.proposal());
  }
}

void main() {
  for (final language in ['pl', 'en']) {
    test(
      'app language $language reaches the single model request without user text',
      () async {
        final llm = LanguageRecordingPhotoLlm();
        final useCase = ProposeMealFromPhotoUseCase(
          client: LocalLlmMealPhotoRecognitionClient(llm),
          candidates: ClarificationCandidateReads(),
        );
        await useCase(
          const MealPhotoInput(mealPhotoPath: 'plate.jpg'),
          languageCode: language,
        );
        expect(llm.requests, hasLength(1));
        for (final request in llm.requests) {
          final data =
              jsonDecode(request.prompt.split('INPUT_DATA:\n').last) as Map;
          expect(data['app_language_code'], language);
          expect(data['description'], isEmpty);
          expect(request.prompt, contains('ALL clarification questions'));
          expect(request.prompt, contains('search_query remains English'));
        }
      },
    );
  }
}
