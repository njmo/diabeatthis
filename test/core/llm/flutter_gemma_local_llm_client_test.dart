import 'dart:typed_data';

import 'package:diabeatthis/core/llm/flutter_gemma_local_llm_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterGemmaLocalLlmClient', () {
    test('forwards text-only requests to the Gemma gateway', () async {
      final gateway = _FakeFlutterGemmaInferenceGateway('{"status":"ok"}');
      final client = FlutterGemmaLocalLlmClient(
        gateway: gateway,
        imageLoader: const _FakeLocalLlmImageLoader({}),
        maxTokens: 2048,
        preferredBackend: PreferredBackend.cpu,
      );

      final response = await client.generate(
        const LocalLlmRequest(prompt: 'Read product data'),
      );

      expect(response.text, '{"status":"ok"}');
      expect(gateway.prompt, 'Read product data');
      expect(gateway.imageBytes, isEmpty);
      expect(gateway.maxTokens, 2048);
      expect(gateway.preferredBackend, PreferredBackend.cpu);
    });

    test('loads image paths and forwards image bytes to the gateway', () async {
      final gateway = _FakeFlutterGemmaInferenceGateway('{"status":"ok"}');
      final client = FlutterGemmaLocalLlmClient(
        gateway: gateway,
        imageLoader: _FakeLocalLlmImageLoader({
          '/tmp/front.jpg': Uint8List.fromList([1, 2, 3]),
          '/tmp/nutrition.jpg': Uint8List.fromList([4, 5, 6]),
        }),
      );

      await client.generate(
        const LocalLlmRequest(
          prompt: 'Read product data',
          imagePaths: ['/tmp/front.jpg', '/tmp/nutrition.jpg'],
        ),
      );

      expect(gateway.imageBytes, [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5, 6]),
      ]);
    });

    test('maps missing active Gemma model to unavailable local LLM', () {
      final client = FlutterGemmaLocalLlmClient(
        gateway: _ThrowingFlutterGemmaInferenceGateway(
          StateError(
            'No active inference model set. Use FlutterGemma.installModel() first.',
          ),
        ),
        imageLoader: const _FakeLocalLlmImageLoader({}),
      );

      expect(
        client.generate(const LocalLlmRequest(prompt: 'Read product data')),
        throwsA(isA<LocalLlmUnavailableException>()),
      );
    });
  });
}

class _FakeLocalLlmImageLoader implements LlmImageLoader {
  final Map<String, Uint8List> imageBytesByPath;

  const _FakeLocalLlmImageLoader(this.imageBytesByPath);

  @override
  Future<List<LlmImageData>> loadAll(List<String> imagePaths) async {
    return imagePaths
        .map(
          (path) => LlmImageData(
            bytes: imageBytesByPath[path]!,
            mimeType: 'image/jpeg',
          ),
        )
        .toList();
  }
}

class _FakeFlutterGemmaInferenceGateway extends FlutterGemmaInferenceGateway {
  final String response;

  String? prompt;
  List<Uint8List>? imageBytes;
  int? maxTokens;
  PreferredBackend? preferredBackend;

  _FakeFlutterGemmaInferenceGateway(this.response);

  @override
  Future<String> generate({
    required String prompt,
    required List<Uint8List> imageBytes,
    required int maxTokens,
    PreferredBackend? preferredBackend,
  }) async {
    this.prompt = prompt;
    this.imageBytes = imageBytes;
    this.maxTokens = maxTokens;
    this.preferredBackend = preferredBackend;
    return response;
  }
}

class _ThrowingFlutterGemmaInferenceGateway
    extends FlutterGemmaInferenceGateway {
  final Object error;

  _ThrowingFlutterGemmaInferenceGateway(this.error);

  @override
  Future<String> generate({
    required String prompt,
    required List<Uint8List> imageBytes,
    required int maxTokens,
    PreferredBackend? preferredBackend,
  }) async {
    throw error;
  }
}
