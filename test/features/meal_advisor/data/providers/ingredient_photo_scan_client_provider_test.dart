import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/providers/firebase_ai_llm_client_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/local_llm_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('ingredientPhotoScanClientProvider', () {
    test('uses debug client by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(ingredientPhotoScanClientProvider),
        isA<DebugIngredientPhotoScanClient>(),
      );
    });

    test('can switch to cloud AI client', () {
      final container = ProviderContainer(
        overrides: [
          firebaseAiLlmClientProvider.overrideWithValue(
            const _FakeLocalLlmClient(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(ingredientPhotoScanClientModeControllerProvider.notifier)
          .setMode(IngredientPhotoScanClientMode.cloudAi);

      expect(
        container.read(ingredientPhotoScanClientProvider),
        isA<LocalLlmIngredientPhotoScanClient>(),
      );
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
