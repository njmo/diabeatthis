import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/local_llm_ingredient_photo_search_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalLlmIngredientPhotoSearchClient', () {
    test('passes prompt and front photo to LLM', () async {
      final llmClient = _FakeLocalLlmClient(
        response: const LocalLlmResponse(text: '{"names":["ziemniaki"]}'),
      );
      final client = LocalLlmIngredientPhotoSearchClient(llmClient: llmClient);

      final response = await client.search(
        const IngredientPhotoScanInput(frontPhotoPath: '/tmp/front.jpg'),
      );

      expect(response, '{"names":["ziemniaki"]}');
      expect(llmClient.request?.imagePaths, ['/tmp/front.jpg']);
      expect(
        llmClient.request?.prompt,
        contains('one front/package/plate photo'),
      );
    });

    test('rejects search without a front photo', () {
      final client = LocalLlmIngredientPhotoSearchClient(
        llmClient: _FakeLocalLlmClient(
          response: const LocalLlmResponse(text: '{}'),
        ),
      );

      expect(client.search(const IngredientPhotoScanInput()), throwsStateError);
    });
  });
}

class _FakeLocalLlmClient implements LocalLlmClient {
  final LocalLlmResponse response;
  LocalLlmRequest? request;

  _FakeLocalLlmClient({required this.response});

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    this.request = request;
    return response;
  }
}
