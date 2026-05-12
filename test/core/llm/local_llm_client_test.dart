import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalLlmRequest', () {
    test('knows when image paths are attached', () {
      const textOnly = LocalLlmRequest(prompt: 'Read product data');
      const withImages = LocalLlmRequest(
        prompt: 'Read product data',
        imagePaths: ['front.jpg', 'nutrition.jpg'],
      );

      expect(textOnly.hasImages, isFalse);
      expect(withImages.hasImages, isTrue);
    });
  });

  group('LocalLlmUnavailableClient', () {
    test(
      'fails explicitly until a concrete local model client is configured',
      () {
        const client = LocalLlmUnavailableClient();

        expect(
          client.generate(const LocalLlmRequest(prompt: 'test')),
          throwsA(isA<LocalLlmUnavailableException>()),
        );
      },
    );
  });
}
