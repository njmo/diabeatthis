import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/llm/local_llm_client.dart';
import 'chat_gpt_auth_exception.dart';

class ChatGptAuthGateway {
  ChatGptAuthGateway({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  static final issuer = Uri.parse('https://auth.openai.com');
  static const resource = 'https://api.openai.com/v1';
  static const timeout = Duration(seconds: 30);

  Future<Map<String, dynamic>> discovery() async {
    final data = await _get(
      issuer.resolve('/.well-known/openid-configuration'),
    );
    if (data['issuer'] != issuer.toString()) {
      throw chatGptAuthorizationFailure();
    }
    return data;
  }

  Uri endpoint(Map<String, dynamic> discovery, String key) {
    final value = discovery[key];
    if (value is! String) throw chatGptAuthorizationFailure();
    final endpoint = Uri.parse(value);
    if (endpoint.scheme != 'https' ||
        endpoint.host != issuer.host ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.port != 443 ||
        endpoint.hasFragment) {
      throw chatGptAuthorizationFailure();
    }
    return endpoint;
  }

  Future<Map<String, dynamic>> keys(Map<String, dynamic> discovery) =>
      _get(endpoint(discovery, 'jwks_uri'));

  Future<Map<String, dynamic>> token(
    Map<String, dynamic> discovery,
    Map<String, String> fields,
  ) => _request(
    () => _send('POST', endpoint(discovery, 'token_endpoint'), fields: fields),
  );

  Future<bool> revoke(
    Map<String, dynamic> discovery, {
    required String clientId,
    required String refreshToken,
  }) async {
    final uri = endpoint(discovery, 'revocation_endpoint');
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _send(
          'POST',
          uri,
          fields: {
            'token': refreshToken,
            'token_type_hint': 'refresh_token',
            'client_id': clientId,
          },
        ).timeout(timeout);
        if (response.statusCode == 200) return true;
        if (response.statusCode < 500) return false;
      } catch (_) {
        // Retry transient failures once without logging credentials.
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _get(Uri uri) =>
      _request(() => _send('GET', uri));

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? fields,
  }) async {
    final request = http.Request(method, uri)..followRedirects = false;
    if (fields != null) request.bodyFields = fields;
    return http.Response.fromStream(await _client.send(request));
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      final response = await send().timeout(timeout);
      if (response.statusCode != 200) {
        throw LlmRequestException(
          failure: response.statusCode == 429
              ? LlmRequestFailure.quotaExceeded
              : response.statusCode >= 500
              ? LlmRequestFailure.unavailable
              : LlmRequestFailure.unauthorized,
          message: 'ChatGPT authorization request failed.',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on LlmRequestException {
      rethrow;
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'ChatGPT authorization timed out.',
      );
    } on SocketException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'ChatGPT authorization network request failed.',
      );
    } on http.ClientException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'ChatGPT authorization network request failed.',
      );
    } catch (_) {
      throw chatGptAuthorizationFailure();
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
