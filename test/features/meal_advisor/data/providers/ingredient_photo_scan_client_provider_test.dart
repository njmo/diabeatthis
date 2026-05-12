import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/providers/firebase_ai_llm_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/local_llm_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('ingredientPhotoScanClientProvider', () {
    test('uses cloud AI client', () {
      final container = ProviderContainer(
        overrides: [
          firebaseAiLlmClientProvider.overrideWithValue(
            const _FakeLocalLlmClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(ingredientPhotoScanClientProvider),
        isA<LocalLlmIngredientPhotoScanClient>(),
      );
      final client =
          container.read(ingredientPhotoScanClientProvider)
              as LocalLlmIngredientPhotoScanClient;
      expect(client.timeout, const Duration(seconds: 30));
    });
  });
}

class _FakeLocalLlmClient implements LocalLlmClient {
  const _FakeLocalLlmClient();

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    return const LocalLlmResponse(text: '{}');
  }
}
