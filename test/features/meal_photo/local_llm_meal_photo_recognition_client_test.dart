import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_proposal_test.dart' as fixtures;

class RecordingPhotoLlm implements LocalLlmClient {
  final requests = <LocalLlmRequest>[];
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    requests.add(request);
    return const LocalLlmResponse(text: 'response');
  }
}

void main() {
  test(
    'both images, user evidence and grounded catalog identities reach the shared LLM client',
    () async {
      final llm = RecordingPhotoLlm();
      final client = LocalLlmMealPhotoRecognitionClient(llm);
      const input = MealPhotoInput(
        mealPhotoPath: '/meal.jpg',
        menuPhotoPath: '/menu.jpg',
        description: 'Contains hidden cheese',
      );
      expect(await client.describe(input), 'response');
      await client.resolve(input, 'description-json', {
        'component': [fixtures.candidate],
      });
      expect(llm.requests.length, 2);
      for (final request in llm.requests) {
        expect(request.imagePaths, ['/meal.jpg', '/menu.jpg']);
        expect(request.prompt, contains('Contains hidden cheese'));
      }
      expect(llm.requests.last.prompt, contains('local:7'));
      expect(llm.requests.last.prompt, contains('description-json'));
      expect(llm.requests.last.prompt, contains('Never subtract fiber twice'));
    },
  );
}
