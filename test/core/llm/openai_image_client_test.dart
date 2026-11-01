import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_image_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const prompt = 'Generate a simple food icon on an opaque background.';
  const imageBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5WQAAAAASUVORK5CYII=';
  final payload = jsonEncode({
    'data': [
      {'b64_json': imageBase64},
    ],
  });

  TypeMatcher<LlmRequestException> failure(LlmRequestFailure expected) =>
      isA<LlmRequestException>().having(
        (error) => error.failure,
        'failure',
        expected,
      );

  test('sends explicit inexpensive PNG image generation parameters', () async {
    final client = OpenAiImageClient(
      accessToken: () async => ' private-api-key ',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.openai.com/v1/images/generations',
        );
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], 'Bearer private-api-key');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {
          'model': 'gpt-image-2.5-flare',
          'prompt': prompt,
          'n': 1,
          'output_format': 'png',
          'background': 'opaque',
          'size': '1024x1024',
          'quality': 'low',
        });
        return http.Response(payload, 200);
      }),
    );
    expect(await client.generate(prompt), base64Decode(imageBase64));
  });

  test('uses the configured image model', () async {
    final client = OpenAiImageClient(
      accessToken: () async => 'private-api-key',
      modelName: 'custom-image-model',
      client: MockClient((request) async {
        expect(jsonDecode(request.body)['model'], 'custom-image-model');
        return http.Response(payload, 200);
      }),
    );
    await client.generate(prompt);
  });

  test('decodes a response split across byte chunks', () async {
    final client = OpenAiImageClient(
      accessToken: () async => 'private-api-key',
      client: MockClient.streaming(
        (request, body) async => http.StreamedResponse(
          Stream.fromIterable(utf8.encode(payload).map((byte) => [byte])),
          200,
        ),
      ),
    );
    expect(await client.generate(prompt), base64Decode(imageBase64));
  });

  for (final status in [302, 401, 403, 408, 429, 500]) {
    final expected = switch (status) {
      401 || 403 => LlmRequestFailure.unauthorized,
      408 => LlmRequestFailure.timeout,
      429 => LlmRequestFailure.quotaExceeded,
      _ => LlmRequestFailure.unavailable,
    };
    test(
      'maps HTTP $status without exposing provider body or credentials',
      () async {
        final client = OpenAiImageClient(
          accessToken: () async => 'private-api-key',
          client: MockClient(
            (_) async => http.Response('private-provider-details', status),
          ),
        );
        await expectLater(
          client.generate(prompt),
          throwsA(
            failure(expected).having(
              (error) => error.toString(),
              'safe message',
              allOf(
                isNot(contains('private-provider-details')),
                isNot(contains('private-api-key')),
              ),
            ),
          ),
        );
      },
    );
  }

  for (final entry in {
    'invalid JSON': 'private-response-body',
    'invalid root': '[]',
    'missing data': '{}',
    'invalid data': '{"data":{}}',
    'empty data': '{"data":[]}',
    'invalid entry': '{"data":[1]}',
    'URL-only response': '{"data":[{"url":"https://example.com/image.png"}]}',
    'empty base64': '{"data":[{"b64_json":""}]}',
    'non-string base64': '{"data":[{"b64_json":1}]}',
    'invalid base64': '{"data":[{"b64_json":"private-invalid!base64"}]}',
  }.entries) {
    test('rejects ${entry.key} without a URL fallback', () async {
      var requests = 0;
      final client = OpenAiImageClient(
        accessToken: () async => 'private-api-key',
        client: MockClient((_) async {
          requests++;
          return http.Response(entry.value, 200);
        }),
      );
      await expectLater(
        client.generate(prompt),
        throwsA(
          failure(LlmRequestFailure.unavailable).having(
            (error) => error.toString(),
            'safe message',
            isNot(contains('private-')),
          ),
        ),
      );
      expect(requests, 1);
    });
  }

  test('rejects an empty API key before sending a request', () async {
    final client = OpenAiImageClient(
      accessToken: () async => ' ',
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    await expectLater(
      client.generate(prompt),
      throwsA(failure(LlmRequestFailure.unauthorized)),
    );
  });

  test('maps network failures without exposing underlying details', () async {
    final client = OpenAiImageClient(
      accessToken: () async => 'private-api-key',
      client: MockClient(
        (_) async => throw http.ClientException('private-network-details'),
      ),
    );
    await expectLater(
      client.generate(prompt),
      throwsA(
        failure(LlmRequestFailure.network).having(
          (error) => error.toString(),
          'safe message',
          isNot(contains('private-network-details')),
        ),
      ),
    );
  });

  test('times out and cancels an unfinished response body', () async {
    final canceled = Completer<void>();
    final bytes = StreamController<List<int>>(onCancel: canceled.complete);
    var aborted = false;
    final client = OpenAiImageClient(
      accessToken: () async => 'private-api-key',
      timeout: const Duration(milliseconds: 10),
      client: MockClient.streaming((request, body) async {
        unawaited(
          (request as http.AbortableRequest).abortTrigger!.then(
            (_) => aborted = true,
          ),
        );
        return http.StreamedResponse(bytes.stream, 200);
      }),
    );
    await expectLater(
      client.generate(prompt),
      throwsA(failure(LlmRequestFailure.timeout)),
    );
    await canceled.future;
    expect(aborted, isTrue);
    await bytes.close();
  });

  test(
    'does not send a request when credentials arrive after timeout',
    () async {
      final token = Completer<String>();
      var requested = false;
      final client = OpenAiImageClient(
        accessToken: () => token.future,
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          requested = true;
          return http.Response(payload, 200);
        }),
      );
      await expectLater(
        client.generate(prompt),
        throwsA(failure(LlmRequestFailure.timeout)),
      );
      token.complete('late-api-key');
      await Future<void>.delayed(Duration.zero);
      expect(requested, isFalse);
    },
  );
}
