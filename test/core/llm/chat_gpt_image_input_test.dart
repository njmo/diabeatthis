import 'dart:convert';
import 'dart:typed_data';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'openai_test_image_loader.dart';

void main() {
  test(
    'ChatGPT subscription sends photo inputs through Responses with OAuth',
    () async {
      const prompt =
          'Read the product name and nutrition values from both photos.';
      const output = '{"name":"Yogurt","carbohydrates":12}';
      final loader = OpenAiTestImageLoader([
        LlmImageData(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/jpeg',
        ),
        LlmImageData(
          bytes: Uint8List.fromList([4, 5, 6]),
          mimeType: 'image/png',
        ),
      ]);
      var requests = 0;
      final client = OpenAiLlmClient(
        modelName: 'account-selected-vision-model',
        accessToken: () async => 'chatgpt-oauth-access-token',
        useChatGptPlan: true,
        maxOutputTokens: 2048,
        imageLoader: loader,
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.openai.com/v1/responses');
          expect(
            request.headers['Authorization'],
            'Bearer chatgpt-oauth-access-token',
          );
          expect(request.headers['Accept'], 'text/event-stream');
          expect(request.followRedirects, isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'account-selected-vision-model');
          expect(body['store'], isFalse);
          expect(body['stream'], isTrue);
          expect(body.containsKey('max_output_tokens'), isFalse);
          expect(body.containsKey('temperature'), isFalse);
          expect(body['input'], [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': prompt},
                {
                  'type': 'input_image',
                  'image_url': 'data:image/jpeg;base64,AQID',
                },
                {
                  'type': 'input_image',
                  'image_url': 'data:image/png;base64,BAUG',
                },
              ],
            },
          ]);
          final completed = {
            'type': 'response.completed',
            'response': {
              'status': 'completed',
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': output},
                  ],
                },
              ],
            },
          };
          return http.Response(
            'event: response.completed\ndata: ${jsonEncode(completed)}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final response = await client.generate(
        const LocalLlmRequest(
          prompt: prompt,
          imagePaths: ['product-front.jpg', 'nutrition-label.png'],
        ),
      );

      expect(response.text, output);
      expect(loader.paths, ['product-front.jpg', 'nutrition-label.png']);
      expect(requests, 1);
    },
  );

  test(
    'ChatGPT photo authorization failure ends without retrying another route',
    () async {
      var requests = 0;
      final client = OpenAiLlmClient(
        modelName: 'account-selected-vision-model',
        accessToken: () async => 'chatgpt-oauth-access-token',
        useChatGptPlan: true,
        imageLoader: OpenAiTestImageLoader([
          LlmImageData(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/jpeg',
          ),
        ]),
        client: MockClient((request) async {
          requests++;
          expect(request.url.toString(), 'https://api.openai.com/v1/responses');
          return http.Response('Account is not eligible', 403);
        }),
      );

      await expectLater(
        client.generate(
          const LocalLlmRequest(
            prompt: 'Read this photo.',
            imagePaths: ['product.jpg'],
          ),
        ),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.unauthorized,
          ),
        ),
      );
      expect(requests, 1);
    },
  );
}
