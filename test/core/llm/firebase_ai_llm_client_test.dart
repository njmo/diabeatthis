import 'dart:typed_data';

import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebaseAiLlmClient', () {
    test('forwards text-only requests to Firebase AI gateway', () async {
      final gateway = _FakeFirebaseAiGenerateContentGateway('{"status":"ok"}');
      final client = FirebaseAiLlmClient(
        gateway: gateway,
        imageLoader: const _FakeLlmImageLoader({}),
        modelName: 'gemini-test',
      );

      final response = await client.generate(
        const LocalLlmRequest(prompt: 'Read product data'),
      );

      expect(response.text, '{"status":"ok"}');
      expect(gateway.modelName, 'gemini-test');
      expect(gateway.prompt, 'Read product data');
      expect(gateway.images, isEmpty);
    });

    test('loads product photos and forwards bytes with MIME types', () async {
      final gateway = _FakeFirebaseAiGenerateContentGateway('{"status":"ok"}');
      final frontImage = LlmImageData(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
      );
      final nutritionImage = LlmImageData(
        bytes: Uint8List.fromList([4, 5, 6]),
        mimeType: 'image/png',
      );
      final client = FirebaseAiLlmClient(
        gateway: gateway,
        imageLoader: _FakeLlmImageLoader({
          '/tmp/front.jpg': frontImage,
          '/tmp/nutrition.png': nutritionImage,
        }),
      );

      await client.generate(
        const LocalLlmRequest(
          prompt: 'Read product data',
          imagePaths: ['/tmp/front.jpg', '/tmp/nutrition.png'],
        ),
      );

      expect(gateway.images, [frontImage, nutritionImage]);
    });
  });
}

class _FakeLlmImageLoader implements LlmImageLoader {
  final Map<String, LlmImageData> imagesByPath;

  const _FakeLlmImageLoader(this.imagesByPath);

  @override
  Future<List<LlmImageData>> loadAll(List<String> imagePaths) async {
    return imagePaths.map((path) => imagesByPath[path]!).toList();
  }
}

class _FakeFirebaseAiGenerateContentGateway
    extends FirebaseAiGenerateContentGateway {
  final String response;

  String? modelName;
  String? prompt;
  List<LlmImageData>? images;

  _FakeFirebaseAiGenerateContentGateway(this.response);

  @override
  Future<String> generate({
    required String modelName,
    required String prompt,
    required List<LlmImageData> images,
  }) async {
    this.modelName = modelName;
    this.prompt = prompt;
    this.images = images;
    return response;
  }
}
