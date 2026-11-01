import 'dart:convert';

import 'package:diabeatthis/common/ai/auth/chat_gpt_identity_verifier.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';

void main() {
  final now = DateTime.utc(2026, 10, 31);
  final seconds = now.millisecondsSinceEpoch ~/ 1000;
  late JsonWebKey key;
  const verifier = ChatGptIdentityVerifier();

  setUpAll(() {
    key = JsonWebKey.generate('RS256', keyBitLength: 2048);
  });

  Map<String, dynamic> claims() => {
    'iss': 'https://auth.openai.com',
    'aud': ['oaiapp_test'],
    'sub': 'verified-subject',
    'nonce': 'expected-nonce',
    'iat': seconds,
    'exp': seconds + 3600,
  };

  String sign(Map<String, dynamic> payload, {JsonWebKey? signingKey}) {
    final builder = JsonWebSignatureBuilder()..jsonContent = payload;
    builder.addRecipient(signingKey ?? key, algorithm: 'RS256');
    return builder.build().toCompactSerialization();
  }

  Future<String> verify(String token) => verifier.verify(
    idToken: token,
    jwks: {
      'keys': [key.toJson()],
    },
    clientId: 'oaiapp_test',
    now: now,
    nonce: 'expected-nonce',
  );

  test(
    'accepts a signed token only after verifying audience, issuer, time and nonce',
    () async {
      expect(await verify(sign(claims())), 'verified-subject');
    },
  );

  test('rejects modified payload without leaking token diagnostics', () async {
    final valid = sign(claims());
    final parts = valid.split('.');
    parts[1] = base64Url
        .encode(utf8.encode(jsonEncode(claims()..['sub'] = 'attacker')))
        .replaceAll('=', '');
    final altered = parts.join('.');
    await expectLater(
      verify(altered),
      throwsA(
        isA<LlmRequestException>().having(
          (error) => error.toString(),
          'safe diagnostics',
          isNot(contains(altered)),
        ),
      ),
    );
  });

  for (final invalid in <String, dynamic>{
    'iss': 'https://untrusted.example',
    'aud': ['oaiapp_other'],
    'exp': seconds,
    'iat': seconds + 60,
    'nbf': seconds + 60,
    'nonce': 'different-nonce',
    'sub': '',
    'azp': 'oaiapp_other',
  }.entries) {
    test('rejects invalid ${invalid.key}', () async {
      await expectLater(
        verify(sign(claims()..[invalid.key] = invalid.value)),
        throwsA(isA<LlmRequestException>()),
      );
    });
  }

  test(
    'rejects a returning identity different from the saved account',
    () async {
      await expectLater(
        verifier.verify(
          idToken: sign(claims()),
          jwks: {
            'keys': [key.toJson()],
          },
          clientId: 'oaiapp_test',
          now: now,
          nonce: 'expected-nonce',
          expectedSubject: 'another-subject',
        ),
        throwsA(isA<LlmRequestException>()),
      );
    },
  );

  test('rejects unsigned tokens even when all claims are valid', () async {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    await expectLater(
      verify('${part({'alg': 'none'})}.${part(claims())}.'),
      throwsA(isA<LlmRequestException>()),
    );
  });
}
