import 'package:jose/jose.dart';

import 'chat_gpt_auth_exception.dart';

class ChatGptIdentityVerifier {
  const ChatGptIdentityVerifier();

  Future<String> verify({
    required String idToken,
    required Map<String, dynamic> jwks,
    required String clientId,
    required DateTime now,
    String? nonce,
    String? expectedSubject,
  }) async {
    try {
      final keyStore = JsonWebKeyStore();
      final keys = jwks['keys'] as List<dynamic>;
      for (final key in keys) {
        final json = Map<String, dynamic>.from(key as Map);
        if (json['kty'] == 'RSA' || json['kty'] == 'EC') {
          keyStore.addKey(JsonWebKey.fromJson(json));
        }
      }
      final token = JsonWebToken.unverified(idToken);
      if (!await token.verify(keyStore, allowedArguments: ['RS256', 'ES256'])) {
        throw chatGptAuthorizationFailure();
      }
      final claims = token.claims.toJson();
      final audience = claims['aud'];
      final audienceMatches =
          audience == clientId ||
          (audience is List && audience.contains(clientId));
      final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
      final expiry = claims['exp'];
      final issuedAt = claims['iat'];
      final notBefore = claims['nbf'];
      final subject = claims['sub'];
      if (claims['iss'] != 'https://auth.openai.com' ||
          !audienceMatches ||
          expiry is! num ||
          expiry <= seconds ||
          issuedAt is! num ||
          issuedAt > seconds + 5 ||
          (notBefore != null &&
              (notBefore is! num || notBefore > seconds + 5)) ||
          (nonce != null && claims['nonce'] != nonce) ||
          (audience is List &&
              audience.length > 1 &&
              claims['azp'] != clientId) ||
          (claims['azp'] != null && claims['azp'] != clientId) ||
          subject is! String ||
          subject.isEmpty ||
          (expectedSubject != null && subject != expectedSubject)) {
        throw chatGptAuthorizationFailure();
      }
      return subject;
    } catch (_) {
      // JWT libraries may include a token in their exception diagnostics.
      throw chatGptAuthorizationFailure();
    }
  }
}
