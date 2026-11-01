import 'dart:async';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/llm/local_llm_client.dart';
import '../ai_credential_store.dart';
import 'chat_gpt_auth_exception.dart';
import 'chat_gpt_auth_gateway.dart';
import 'chat_gpt_callback_page.dart';
import 'chat_gpt_identity_verifier.dart';
import 'chat_gpt_loopback_callback.dart';
import 'chat_gpt_oauth_transaction.dart';
import 'chat_gpt_session.dart';

class ChatGptAuthService {
  ChatGptAuthService({
    required this.credentials,
    ChatGptAuthGateway? gateway,
    this.identityVerifier = const ChatGptIdentityVerifier(),
    Future<bool> Function(Uri)? openBrowser,
    DateTime Function()? now,
    this.callbackPage,
    this.signInTimeout = const Duration(minutes: 5),
  }) : gateway = gateway ?? ChatGptAuthGateway(),
       openBrowser = openBrowser ?? openSystemBrowser,
       now = now ?? DateTime.now;

  final AiCredentialStore credentials;
  final ChatGptAuthGateway gateway;
  final ChatGptIdentityVerifier identityVerifier;
  final Future<bool> Function(Uri) openBrowser;
  final DateTime Function() now;
  final Duration signInTimeout;
  final ChatGptCallbackPage Function()? callbackPage;
  static const sessionKey = 'ai.chatgpt.session.v1';
  static const hostKey = 'ai.chatgpt.host.v1';
  static const scopes =
      'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';

  int _generation = 0;
  bool _disposed = false;
  Future<void>? _signingIn;
  Future<String>? _refreshing;
  Future<void>? _signingOut;
  Future<void> _storageQueue = Future<void>.value();
  ChatGptLoopbackCallback? _callback;

  static Future<bool> openSystemBrowser(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<bool> get isConnected async =>
      !_disposed && _signingOut == null && (await _load())?.isConnected == true;

  Future<void> signIn() {
    if (_disposed || _signingOut != null) {
      return Future<void>.error(chatGptAuthorizationFailure());
    }
    return _signingIn ??= _signIn().whenComplete(() => _signingIn = null);
  }

  Future<void> _signIn() async {
    final generation = ++_generation;
    ChatGptLoopbackCallback? callback;
    try {
      final previous = await _load();
      final discovery = await gateway.discovery();
      var host = await credentials.read(hostKey);
      if (host == null) {
        host = ChatGptOAuthTransaction.newHostId();
        await _write(generation, () => credentials.write(hostKey, host!));
      }
      _requireCurrent(generation);
      final transaction = ChatGptOAuthTransaction();
      callback = await ChatGptLoopbackCallback.start(
        transaction.state,
        page: callbackPage?.call(),
      );
      _callback = callback;
      _requireCurrent(generation);
      final redirect = callback.redirectUri.toString();
      final authorization = gateway
          .endpoint(discovery, 'authorization_endpoint')
          .replace(
            queryParameters: {
              'client_id': previous?.clientId ?? 'dynamic_agent_client',
              if (previous == null) 'agent_name_hint': 'Diabeatthis',
              'ext_agent_host_id': host,
              if (previous?.idToken != null)
                'id_token_hint': previous!.idToken!,
              'response_type': 'code',
              'redirect_uri': redirect,
              'scope': scopes,
              'resource': ChatGptAuthGateway.resource,
              'state': transaction.state,
              'nonce': transaction.nonce,
              'code_challenge_method': 'S256',
              'code_challenge': transaction.challenge,
            },
          );
      final pending = callback.result.timeout(signInTimeout);
      unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
      if (!await openBrowser(authorization).timeout(signInTimeout)) {
        throw chatGptAuthorizationFailure();
      }
      final uri = await pending;
      for (final key in ['state', 'code', 'client_id', 'error']) {
        if ((uri.queryParametersAll[key]?.length ?? 0) > 1) {
          throw chatGptAuthorizationFailure();
        }
      }
      final query = uri.queryParameters;
      if (query['state'] != transaction.state || query.containsKey('error')) {
        throw chatGptAuthorizationFailure();
      }
      final clientId = query['client_id'] ?? previous?.clientId;
      final code = query['code'];
      if (clientId == null ||
          clientId.isEmpty ||
          clientId == 'dynamic_agent_client' ||
          code == null ||
          code.isEmpty ||
          (previous != null && previous.clientId != clientId)) {
        throw chatGptAuthorizationFailure();
      }
      _requireCurrent(generation);
      final response = await gateway.token(discovery, {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'code': code,
        'code_verifier': transaction.verifier,
        'redirect_uri': redirect,
        'resource': ChatGptAuthGateway.resource,
      });
      final id = response['id_token'];
      if (id is! String) throw chatGptAuthorizationFailure();
      final subject = await identityVerifier.verify(
        idToken: id,
        jwks: await gateway.keys(discovery),
        clientId: clientId,
        now: now(),
        nonce: transaction.nonce,
        expectedSubject: previous?.subject,
      );
      final session = ChatGptSession.fromTokenResponse(
        clientId: clientId,
        subject: subject,
        response: response,
        now: now(),
      );
      await _save(generation, session);
    } on LlmRequestException {
      rethrow;
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'ChatGPT sign-in timed out.',
      );
    } catch (_) {
      throw chatGptAuthorizationFailure();
    } finally {
      await callback?.close();
      if (identical(_callback, callback)) _callback = null;
    }
  }

  Future<String> accessToken() {
    if (_disposed || _signingOut != null || _signingIn != null) {
      return Future<String>.error(chatGptAuthorizationFailure());
    }
    // Serialize the credential read as well as renewal: a delayed read must not
    // start a second refresh using an already-rotated refresh token.
    return _refreshing ??= _accessToken().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<String> _accessToken() async {
    final generation = _generation;
    final session = await _load();
    _requireCurrent(generation);
    if (session == null || !session.isConnected) {
      throw chatGptAuthorizationFailure();
    }
    final expiry = session.expiresAt;
    final current = now().toUtc();
    if (expiry != null &&
        expiry.isAfter(current.add(const Duration(minutes: 1)))) {
      return session.accessToken!;
    }
    if (session.earliestRefreshAt?.isAfter(current) == true) {
      if (expiry?.isAfter(current) == true) return session.accessToken!;
      throw chatGptAuthorizationFailure();
    }
    return _refresh(generation, session);
  }

  Future<String> _refresh(int generation, ChatGptSession previous) async {
    try {
      final discovery = await gateway.discovery();
      final response = await gateway.token(discovery, {
        'grant_type': 'refresh_token',
        'client_id': previous.clientId,
        'refresh_token': previous.refreshToken!,
        'resource': ChatGptAuthGateway.resource,
      });
      final id = response['id_token'];
      if (id != null) {
        if (id is! String) throw chatGptAuthorizationFailure();
        await identityVerifier.verify(
          idToken: id,
          jwks: await gateway.keys(discovery),
          clientId: previous.clientId,
          now: now(),
          expectedSubject: previous.subject,
        );
      }
      final session = ChatGptSession.fromTokenResponse(
        clientId: previous.clientId,
        subject: previous.subject,
        response: response,
        now: now(),
        previous: previous,
      );
      await _save(generation, session);
      return session.accessToken!;
    } on LlmRequestException catch (error) {
      if (error.failure == LlmRequestFailure.unauthorized &&
          generation == _generation) {
        await _save(generation, previous.signedOut());
      }
      rethrow;
    } catch (_) {
      throw chatGptAuthorizationFailure();
    }
  }

  Future<void> signOut() {
    return _signingOut ??= _signOut().whenComplete(() => _signingOut = null);
  }

  Future<void> _signOut() async {
    final generation = ++_generation;
    await _callback?.close();
    await _storageQueue;
    final session = await _load();
    if (session == null) return;
    var confirmed = session.refreshToken == null;
    try {
      if (session.refreshToken != null) {
        confirmed = await gateway.revoke(
          await gateway.discovery(),
          clientId: session.clientId,
          refreshToken: session.refreshToken!,
        );
      }
    } catch (_) {
      confirmed = false;
    } finally {
      await _save(generation, session.signedOut());
    }
    if (!confirmed) throw const ChatGptRevocationUnconfirmedException();
  }

  Future<ChatGptSession?> _load() async {
    try {
      final value = await credentials.read(sessionKey);
      if (value == null) return null;
      return ChatGptSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      throw chatGptAuthorizationFailure();
    }
  }

  Future<void> _save(int generation, ChatGptSession session) => _write(
    generation,
    () => credentials.write(sessionKey, jsonEncode(session.toJson())),
  );

  Future<void> _write(int generation, Future<void> Function() write) {
    final operation = _storageQueue.then((_) async {
      _requireCurrent(generation);
      await write();
      _requireCurrent(generation);
    });
    _storageQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  void _requireCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw chatGptAuthorizationFailure();
    }
  }

  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_callback?.close());
    gateway.dispose();
  }
}
