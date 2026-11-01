import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/ai/ai_credential_store.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_gateway.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_identity_verifier.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_session.dart';

class MemoryAiCredentialStore implements AiCredentialStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  ChatGptSession? get session {
    final value = values[ChatGptAuthService.sessionKey];
    return value == null ? null : ChatGptSession.fromJson(jsonDecode(value));
  }

  void storeSession(ChatGptSession session) {
    values[ChatGptAuthService.sessionKey] = jsonEncode(session.toJson());
  }
}

class TestChatGptGateway extends ChatGptAuthGateway {
  final List<Map<String, String>> requests = [];
  Future<Map<String, dynamic>> Function(Map<String, String>)? onToken;
  bool revoked = false;
  bool revocationSucceeds = true;

  @override
  Future<Map<String, dynamic>> discovery() async => {
    'issuer': 'https://auth.openai.com',
    'authorization_endpoint': 'https://auth.openai.com/api/accounts/authorize',
    'token_endpoint': 'https://auth.openai.com/api/accounts/oauth/token',
    'jwks_uri': 'https://auth.openai.com/.well-known/jwks.json',
    'revocation_endpoint': 'https://auth.openai.com/api/accounts/oauth/revoke',
  };

  @override
  Future<Map<String, dynamic>> keys(Map<String, dynamic> discovery) async => {
    'keys': [],
  };

  @override
  Future<Map<String, dynamic>> token(
    Map<String, dynamic> discovery,
    Map<String, String> fields,
  ) async {
    requests.add(fields);
    return onToken == null ? tokenResponse() : await onToken!(fields);
  }

  static Map<String, dynamic> tokenResponse({
    String access = 'access',
    String refresh = 'refresh',
  }) => {
    'access_token': access,
    'refresh_token': refresh,
    'id_token': 'identity',
    'token_type': 'Bearer',
    'expires_in': 3600,
    'scope': ChatGptAuthService.scopes,
  };

  @override
  Future<bool> revoke(
    Map<String, dynamic> discovery, {
    required String clientId,
    required String refreshToken,
  }) async {
    revoked = true;
    return revocationSucceeds;
  }
}

class TestChatGptIdentityVerifier extends ChatGptIdentityVerifier {
  String subject = 'subject';
  String? verifiedNonce;
  String? expectedClient;

  @override
  Future<String> verify({
    required String idToken,
    required Map<String, dynamic> jwks,
    required String clientId,
    required DateTime now,
    String? nonce,
    String? expectedSubject,
  }) async {
    verifiedNonce = nonce;
    expectedClient = clientId;
    return subject;
  }
}

Future<int> completeChatGptCallback(
  Uri authorization, {
  String clientId = 'oaiapp_test',
  String? state,
  Map<String, String> extra = const {},
}) async {
  final callback = Uri.parse(authorization.queryParameters['redirect_uri']!)
      .replace(
        queryParameters: {
          'state': state ?? authorization.queryParameters['state']!,
          'code': 'authorization-code',
          'client_id': clientId,
          ...extra,
        },
      );
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(callback)).close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

ChatGptSession expiredChatGptSession(DateTime now) => ChatGptSession(
  clientId: 'oaiapp_test',
  subject: 'subject',
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  idToken: 'identity',
  expiresAt: now.subtract(const Duration(seconds: 1)),
  scopes: ChatGptAuthService.scopes.split(' '),
);
