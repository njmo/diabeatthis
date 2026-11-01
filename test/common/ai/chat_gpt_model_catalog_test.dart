import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/ai/chat_gpt_model_catalog.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads account catalog, filters visibility, deduplicates, and preserves order',
    () async {
      final catalog = ChatGptModelCatalog(
        accessToken: () async => 'account-token',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.openai.com/v1/models');
          expect(request.headers['Authorization'], 'Bearer account-token');
          expect(request.followRedirects, isFalse);
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'slug': 'second-alphabetically',
                  'display_name': 'Preferred',
                  'visibility': 'list',
                },
                {'slug': 'hidden-model', 'visibility': 'hidden'},
                {
                  'slug': 'first-alphabetically',
                  'display_name': 'Another model',
                  'visibility': 'list',
                },
                {
                  'slug': 'second-alphabetically',
                  'display_name': 'Duplicate',
                  'visibility': 'list',
                },
                {'slug': 'fallback-label', 'visibility': 'list'},
                {'slug': '', 'visibility': 'list'},
                {'slug': 12, 'visibility': 'list'},
                'invalid-entry',
              ],
            }),
            200,
          );
        }),
      );
      final models = await catalog.load();
      expect(models.map((model) => model.id), [
        'second-alphabetically',
        'first-alphabetically',
        'fallback-label',
      ]);
      expect(models.map((model) => model.label), [
        'Preferred',
        'Another model',
        'fallback-label',
      ]);
    },
  );

  for (final status in [401, 403, 429, 500]) {
    final expected = switch (status) {
      401 || 403 => LlmRequestFailure.unauthorized,
      429 => LlmRequestFailure.quotaExceeded,
      _ => LlmRequestFailure.unavailable,
    };
    test('maps HTTP $status without exposing response bodies', () async {
      final catalog = ChatGptModelCatalog(
        accessToken: () async => 'account-token',
        client: MockClient(
          (_) async => http.Response('private-server-detail', status),
        ),
      );
      await expectLater(
        catalog.load(),
        throwsA(
          isA<LlmRequestException>()
              .having((error) => error.failure, 'failure', expected)
              .having(
                (error) => error.toString(),
                'safe message',
                isNot(contains('private-server-detail')),
              ),
        ),
      );
    });
  }

  for (final entry in {
    'invalid JSON': 'private-server-detail',
    'array root': '[]',
    'regular API catalog': '{"data":[]}',
    'invalid models': '{"models":"private-server-detail"}',
  }.entries) {
    test('rejects ${entry.key} with a sanitized error', () async {
      final catalog = ChatGptModelCatalog(
        accessToken: () async => 'account-token',
        client: MockClient((_) async => http.Response(entry.value, 200)),
      );
      await expectLater(
        catalog.load(),
        throwsA(
          isA<LlmRequestException>()
              .having(
                (error) => error.failure,
                'failure',
                LlmRequestFailure.unavailable,
              )
              .having(
                (error) => error.toString(),
                'safe message',
                isNot(contains('private-server-detail')),
              ),
        ),
      );
    });
  }

  test('sanitizes network exceptions', () async {
    final catalog = ChatGptModelCatalog(
      accessToken: () async => 'account-token',
      client: MockClient(
        (_) async => throw http.ClientException('private-network-detail'),
      ),
    );
    await expectLater(
      catalog.load(),
      throwsA(
        isA<LlmRequestException>()
            .having(
              (error) => error.failure,
              'failure',
              LlmRequestFailure.network,
            )
            .having(
              (error) => error.toString(),
              'safe message',
              isNot(contains('private-network-detail')),
            ),
      ),
    );
  });

  test('does not send HTTP requests when credential retrieval fails', () async {
    var requested = false;
    final catalog = ChatGptModelCatalog(
      accessToken: () async => throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'Sign in required',
      ),
      client: MockClient((_) async {
        requested = true;
        return http.Response('{"models":[]}', 200);
      }),
    );
    await expectLater(
      catalog.load(),
      throwsA(
        isA<LlmRequestException>().having(
          (error) => error.failure,
          'failure',
          LlmRequestFailure.unauthorized,
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test('rejects an empty credential before making a network call', () async {
    var requested = false;
    final catalog = ChatGptModelCatalog(
      accessToken: () async => '  ',
      client: MockClient((_) async {
        requested = true;
        return http.Response('{"models":[]}', 200);
      }),
    );
    await expectLater(
      catalog.load(),
      throwsA(
        isA<LlmRequestException>().having(
          (error) => error.failure,
          'failure',
          LlmRequestFailure.unauthorized,
        ),
      ),
    );
    expect(requested, isFalse);
  });

  test(
    'does not make a delayed request after credential retrieval times out',
    () {
      fakeAsync((time) {
        final token = Completer<String>();
        Object? failure;
        var requested = false;
        final catalog = ChatGptModelCatalog(
          accessToken: () => token.future,
          client: MockClient((_) async {
            requested = true;
            return http.Response('{"models":[]}', 200);
          }),
        );
        unawaited(
          catalog.load().then<void>(
            (_) {},
            onError: (Object error) => failure = error,
          ),
        );
        time.flushMicrotasks();
        time.elapse(const Duration(seconds: 31));
        expect(
          failure,
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.timeout,
          ),
        );
        token.complete('late-token');
        time.flushMicrotasks();
        expect(requested, isFalse);
      });
    },
  );
}
