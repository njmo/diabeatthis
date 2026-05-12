import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/local_llm_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalLlmIngredientPhotoScanClient', () {
    test('passes prompt and product photos to local LLM', () async {
      final llmClient = _FakeLocalLlmClient(
        response: const LocalLlmResponse(text: '{"status":"recognized"}'),
      );
      final runtimeClient = LocalLlmIngredientPhotoScanClient(
        llmClient: llmClient,
        prompt: 'scan prompt',
        timeout: const Duration(seconds: 30),
      );

      final response = await runtimeClient.scan(
        const IngredientPhotoScanInput(
          frontPhotoPath: 'front.jpg',
          nutritionLabelPhotoPath: 'nutrition.jpg',
        ),
      );

      expect(response, '{"status":"recognized"}');
      expect(llmClient.request?.prompt, 'scan prompt');
      expect(llmClient.request?.imagePaths, ['front.jpg', 'nutrition.jpg']);
      expect(llmClient.request?.timeout, const Duration(seconds: 30));
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
