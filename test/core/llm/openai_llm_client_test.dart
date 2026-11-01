import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'openai_test_image_loader.dart';

void main() {
  const prompt = 'Return JSON with the status.';
  const resultText = '{"status":"ok"}';

  Map<String, Object?> completed([String text = resultText]) => {
    'type': 'response.completed',
    'response': {
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': text},
          ],
        },
      ],
    },
  };

  String event(Map<String, Object?> value) =>
      'event: ${value['type']}\ndata: ${jsonEncode(value)}\n\n';

  TypeMatcher<LlmRequestException> failure(LlmRequestFailure expected) =>
      isA<LlmRequestException>().having(
        (error) => error.failure,
        'failure',
        expected,
      );

  for (final useChatGptPlan in [false, true]) {
    test(
      'sends ${useChatGptPlan ? 'ChatGPT plan' : 'API key'} request contract',
      () async {
        final transport = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'https://api.openai.com/v1/responses');
          expect(request.headers['Authorization'], 'Bearer test-credential');
          expect(request.headers['Accept'], 'text/event-stream');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['model'], 'configured-model');
          expect(body['store'], isFalse);
          expect(body['stream'], isTrue);
          expect(body.containsKey('max_output_tokens'), !useChatGptPlan);
          if (!useChatGptPlan) expect(body['max_output_tokens'], 8192);
          expect(body.containsKey('temperature'), isFalse);
          expect(body['input'], [
            {
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': prompt},
              ],
            },
          ]);
          return http.Response(event(completed()), 200);
        });
        final client = OpenAiLlmClient(
          modelName: 'configured-model',
          accessToken: () async => 'test-credential',
          useChatGptPlan: useChatGptPlan,
          client: transport,
        );

        expect(
          (await client.generate(const LocalLlmRequest(prompt: prompt))).text,
          resultText,
        );
      },
    );
  }

  test('encodes all image inputs and preserves prompt order', () async {
    final loader = OpenAiTestImageLoader([
      LlmImageData(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/jpeg',
      ),
      LlmImageData(bytes: Uint8List.fromList([4, 5]), mimeType: 'image/png'),
    ]);
    final client = OpenAiLlmClient(
      modelName: 'vision-model',
      accessToken: () async => 'test-credential',
      imageLoader: loader,
      client: MockClient((request) async {
        final input = (jsonDecode(request.body) as Map)['input'] as List;
        expect(input.single['content'], [
          {'type': 'input_text', 'text': prompt},
          {'type': 'input_image', 'image_url': 'data:image/jpeg;base64,AQID'},
          {'type': 'input_image', 'image_url': 'data:image/png;base64,BAU='},
        ]);
        return http.Response(event(completed()), 200);
      }),
    );

    await client.generate(
      const LocalLlmRequest(
        prompt: prompt,
        imagePaths: ['front.jpg', 'label.png'],
      ),
    );
    expect(loader.paths, ['front.jpg', 'label.png']);
  });

  for (final useChatGptPlan in [false, true]) {
    test(
      'custom output budget ${useChatGptPlan ? 'is omitted for ChatGPT' : 'is used for API'}',
      () async {
        final client = OpenAiLlmClient(
          modelName: 'configured-model',
          accessToken: () async => 'test-credential',
          useChatGptPlan: useChatGptPlan,
          maxOutputTokens: 512,
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            if (useChatGptPlan) {
              expect(body.containsKey('max_output_tokens'), isFalse);
            } else {
              expect(body['max_output_tokens'], 512);
            }
            return http.Response(event(completed()), 200);
          }),
        );
        await client.generate(const LocalLlmRequest(prompt: prompt));
      },
    );
  }

  test(
    'decodes byte-sized SSE chunks including multibyte UTF-8 and CRLF',
    () async {
      const text = '{"food":"żółty ser"}';
      final payload =
          ': heartbeat\r\n\r\n${event({'type': 'response.output_text.delta', 'delta': text})}${event(completed(text))}'
              .replaceAll('\n', '\r\n');
      final client = OpenAiLlmClient(
        modelName: 'configured-model',
        accessToken: () async => 'test-credential',
        client: MockClient.streaming((request, body) async {
          return http.StreamedResponse(
            Stream.fromIterable(utf8.encode(payload).map((byte) => [byte])),
            200,
          );
        }),
      );
      expect(
        (await client.generate(const LocalLlmRequest(prompt: prompt))).text,
        text,
      );
    },
  );

  for (final status in [401, 403, 429, 408, 500]) {
    final expected = switch (status) {
      401 || 403 => LlmRequestFailure.unauthorized,
      429 => LlmRequestFailure.quotaExceeded,
      408 => LlmRequestFailure.timeout,
      _ => LlmRequestFailure.unavailable,
    };
    test(
      'maps HTTP $status without exposing provider response details',
      () async {
        final client = OpenAiLlmClient(
          modelName: 'configured-model',
          accessToken: () async => 'test-credential',
          client: MockClient(
            (_) async => http.Response('private-data', status),
          ),
        );
        await expectLater(
          client.generate(const LocalLlmRequest(prompt: prompt)),
          throwsA(
            failure(expected).having(
              (error) => error.toString(),
              'safe description',
              isNot(contains('private-data')),
            ),
          ),
        );
      },
    );
  }

  test('handles streamed quota errors without provider message text', () async {
    final client = OpenAiLlmClient(
      modelName: 'configured-model',
      accessToken: () async => 'test-credential',
      client: MockClient(
        (_) async => http.Response(
          event({
            'type': 'response.failed',
            'response': {
              'status': 'failed',
              'error': {
                'code': 'insufficient_quota',
                'message': 'private-data',
              },
            },
          }),
          200,
        ),
      ),
    );
    await expectLater(
      client.generate(const LocalLlmRequest(prompt: prompt)),
      throwsA(failure(LlmRequestFailure.quotaExceeded)),
    );
  });

  test(
    'retains partial output only in explicit output limit exception',
    () async {
      const partial = '{"status":';
      final client = OpenAiLlmClient(
        modelName: 'configured-model',
        accessToken: () async => 'test-credential',
        client: MockClient(
          (_) async => http.Response(
            event({'type': 'response.output_text.delta', 'delta': partial}) +
                event({
                  'type': 'response.incomplete',
                  'response': {
                    'status': 'incomplete',
                    'incomplete_details': {'reason': 'max_output_tokens'},
                  },
                }),
            200,
          ),
        ),
      );
      await expectLater(
        client.generate(const LocalLlmRequest(prompt: prompt)),
        throwsA(
          isA<LlmOutputLimitException>()
              .having((error) => error.response, 'partial response', partial)
              .having(
                (error) => error.toString(),
                'safe description',
                isNot(contains(partial)),
              ),
        ),
      );
    },
  );

  for (final entry in {
    'empty output': event(completed('')),
    'missing completion': event({
      'type': 'response.output_text.delta',
      'delta': resultText,
    }),
    'failed completion': event({
      'type': 'response.completed',
      'response': {'status': 'failed'},
    }),
    'malformed data': 'data: malformed-private-data\n\n',
    'incomplete filtered content': event({
      'type': 'response.incomplete',
      'response': {
        'incomplete_details': {'reason': 'content_filter'},
      },
    }),
    'refusal': event({
      'type': 'response.completed',
      'response': {
        'status': 'completed',
        'output': [
          {
            'type': 'message',
            'content': [
              {'type': 'refusal', 'refusal': 'Refused'},
            ],
          },
        ],
      },
    }),
  }.entries) {
    test('rejects ${entry.key}', () async {
      final client = OpenAiLlmClient(
        modelName: 'configured-model',
        accessToken: () async => 'test-credential',
        client: MockClient((_) async => http.Response(entry.value, 200)),
      );
      await expectLater(
        client.generate(const LocalLlmRequest(prompt: prompt)),
        throwsA(failure(LlmRequestFailure.unavailable)),
      );
    });
  }

  test(
    'maps network failures without including underlying credential details',
    () async {
      final client = OpenAiLlmClient(
        modelName: 'configured-model',
        accessToken: () async => 'test-credential',
        client: MockClient(
          (_) async => throw http.ClientException('private-data'),
        ),
      );
      await expectLater(
        client.generate(const LocalLlmRequest(prompt: prompt)),
        throwsA(failure(LlmRequestFailure.network)),
      );
    },
  );

  test('times out and cancels an unfinished stream', () async {
    final canceled = Completer<void>();
    final bytes = StreamController<List<int>>(onCancel: canceled.complete);
    var aborted = false;
    final client = OpenAiLlmClient(
      modelName: 'configured-model',
      accessToken: () async => 'test-credential',
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
      client.generate(
        const LocalLlmRequest(
          prompt: prompt,
          timeout: Duration(milliseconds: 10),
        ),
      ),
      throwsA(failure(LlmRequestFailure.timeout)),
    );
    await canceled.future;
    expect(aborted, isTrue);
    await bytes.close();
  });

  test('does not send a request after credential loading times out', () async {
    final credentials = Completer<String>();
    var requests = 0;
    final client = OpenAiLlmClient(
      modelName: 'configured-model',
      accessToken: () => credentials.future,
      client: MockClient((_) async {
        requests++;
        return http.Response(event(completed()), 200);
      }),
    );
    await expectLater(
      client.generate(
        const LocalLlmRequest(
          prompt: prompt,
          timeout: Duration(milliseconds: 1),
        ),
      ),
      throwsA(failure(LlmRequestFailure.timeout)),
    );
    credentials.complete('test-credential');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
  });

  test('rejects missing credentials without a network call', () async {
    final client = OpenAiLlmClient(
      modelName: 'configured-model',
      accessToken: () async => '',
      client: MockClient(
        (_) async => throw StateError('Unexpected HTTP request'),
      ),
    );
    await expectLater(
      client.generate(const LocalLlmRequest(prompt: prompt)),
      throwsA(failure(LlmRequestFailure.unauthorized)),
    );
  });
}
