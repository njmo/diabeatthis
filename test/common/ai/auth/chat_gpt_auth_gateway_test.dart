import 'dart:convert';

import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_gateway.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'never sends credentials to a discovery endpoint outside the issuer origin',
    () async {
      final gateway = ChatGptAuthGateway(
        client: MockClient((_) async {
          fail('Credentials must not be sent to the untrusted endpoint.');
        }),
      );
      await expectLater(
        gateway.token(
          {'token_endpoint': 'https://untrusted.example/token'},
          {'refresh_token': 'sensitive-token'},
        ),
        throwsA(isA<LlmRequestException>()),
      );
    },
  );

  test('rejects a mismatched issuer in discovery', () async {
    final gateway = ChatGptAuthGateway(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({'issuer': 'https://untrusted.example'}),
          200,
        );
      }),
    );
    await expectLater(gateway.discovery(), throwsA(isA<LlmRequestException>()));
  });

  test(
    'token errors are classified without retaining response content',
    () async {
      for (final status in [400, 401, 429, 503]) {
        final gateway = ChatGptAuthGateway(
          client: MockClient((_) async {
            return http.Response(
              'sensitive-token raw provider diagnostic',
              status,
            );
          }),
        );
        await expectLater(
          gateway.token(
            {
              'token_endpoint':
                  'https://auth.openai.com/api/accounts/oauth/token',
            },
            {'refresh_token': 'sensitive-token'},
          ),
          throwsA(
            isA<LlmRequestException>()
                .having(
                  (error) => error.toString(),
                  'safe error',
                  isNot(contains('sensitive-token')),
                )
                .having((error) => error.cause, 'cause', isNull),
          ),
        );
      }
    },
  );

  test(
    'revocation uses the refresh token and succeeds with an empty response',
    () async {
      final gateway = ChatGptAuthGateway(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.bodyFields, {
            'token': 'refresh',
            'token_type_hint': 'refresh_token',
            'client_id': 'oaiapp_test',
          });
          return http.Response('', 200);
        }),
      );
      expect(
        await gateway.revoke(
          {
            'revocation_endpoint':
                'https://auth.openai.com/api/accounts/oauth/revoke',
          },
          clientId: 'oaiapp_test',
          refreshToken: 'refresh',
        ),
        isTrue,
      );
    },
  );
}
