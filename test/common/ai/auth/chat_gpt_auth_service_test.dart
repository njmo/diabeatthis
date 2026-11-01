import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_exception.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_gpt_auth_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 31);
  late MemoryAiCredentialStore store;
  late TestChatGptGateway gateway;
  late TestChatGptIdentityVerifier verifier;

  setUp(() {
    store = MemoryAiCredentialStore();
    gateway = TestChatGptGateway();
    verifier = TestChatGptIdentityVerifier();
  });

  test(
    'registers using PKCE, validates nonce, and stores issued registration',
    () async {
      late Uri authorization;
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: verifier,
        now: () => now,
        openBrowser: (uri) async {
          authorization = uri;
          expect(
            await completeChatGptCallback(uri, state: 'wrong'),
            HttpStatus.badRequest,
          );
          expect(await completeChatGptCallback(uri), HttpStatus.noContent);
          return true;
        },
      );
      addTearDown(service.dispose);
      await service.signIn();
      final query = authorization.queryParameters;
      expect(query['client_id'], 'dynamic_agent_client');
      expect(query['agent_name_hint'], 'Diabeatthis');
      expect(query['ext_agent_host_id'], startsWith('urn:uuid:'));
      expect(query['resource'], 'https://api.openai.com/v1');
      final request = gateway.requests.single;
      expect(request['client_id'], 'oaiapp_test');
      expect(request['redirect_uri'], query['redirect_uri']);
      expect(
        query['code_challenge'],
        base64Url
            .encode(
              sha256.convert(ascii.encode(request['code_verifier']!)).bytes,
            )
            .replaceAll('=', ''),
      );
      expect(verifier.verifiedNonce, query['nonce']);
      expect(verifier.expectedClient, 'oaiapp_test');
      expect(await service.isConnected, isTrue);
      expect(await service.accessToken(), 'access');
      expect(store.session!.clientId, 'oaiapp_test');
    },
  );

  test(
    'reuses registration and host after sign out without retained token hints',
    () async {
      final authorizations = <Uri>[];
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: verifier,
        now: () => now,
        openBrowser: (uri) async {
          authorizations.add(uri);
          await completeChatGptCallback(uri);
          return true;
        },
      );
      addTearDown(service.dispose);
      await service.signIn();
      await service.signOut();
      expect(gateway.revoked, isTrue);
      expect(await service.isConnected, isFalse);
      expect(store.session!.accessToken, isNull);
      expect(store.session!.idToken, isNull);
      await service.signIn();
      final first = authorizations.first.queryParameters;
      final second = authorizations.last.queryParameters;
      expect(second['client_id'], 'oaiapp_test');
      expect(second['agent_name_hint'], isNull);
      expect(second['id_token_hint'], isNull);
      expect(second['ext_agent_host_id'], first['ext_agent_host_id']);
      expect(second['state'], isNot(first['state']));
      expect(second['nonce'], isNot(first['nonce']));
    },
  );

  test('denied authorization never exchanges code or stores tokens', () async {
    final service = ChatGptAuthService(
      credentials: store,
      gateway: gateway,
      identityVerifier: verifier,
      openBrowser: (uri) async {
        await completeChatGptCallback(uri, extra: {'error': 'access_denied'});
        return true;
      },
    );
    addTearDown(service.dispose);
    await expectLater(service.signIn(), throwsA(isA<LlmRequestException>()));
    expect(gateway.requests, isEmpty);
    expect(store.session, isNull);
  });

  test('a changed issued client ID cannot replace a saved account', () async {
    store.storeSession(expiredChatGptSession(now));
    final service = ChatGptAuthService(
      credentials: store,
      gateway: gateway,
      identityVerifier: verifier,
      openBrowser: (uri) async {
        await completeChatGptCallback(uri, clientId: 'oaiapp_other');
        return true;
      },
    );
    addTearDown(service.dispose);
    await expectLater(service.signIn(), throwsA(isA<LlmRequestException>()));
    expect(gateway.requests, isEmpty);
    expect(store.session!.clientId, 'oaiapp_test');
    expect(store.session!.refreshToken, 'old-refresh');
  });

  test('missing plan scope does not activate a session', () async {
    gateway.onToken = (_) async =>
        TestChatGptGateway.tokenResponse()..['scope'] = 'openid profile email';
    final service = ChatGptAuthService(
      credentials: store,
      gateway: gateway,
      identityVerifier: verifier,
      openBrowser: (uri) async {
        await completeChatGptCallback(uri);
        return true;
      },
    );
    addTearDown(service.dispose);
    await expectLater(service.signIn(), throwsA(isA<LlmRequestException>()));
    expect(store.session, isNull);
  });

  test(
    'concurrent access refreshes once and replaces rotating credentials together',
    () async {
      store.storeSession(expiredChatGptSession(now));
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      gateway.onToken = (_) {
        started.complete();
        return response.future;
      };
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: verifier,
        now: () => now,
      );
      addTearDown(service.dispose);
      final first = service.accessToken();
      final second = service.accessToken();
      await started.future;
      response.complete(
        TestChatGptGateway.tokenResponse(
          access: 'new-access',
          refresh: 'new-refresh',
        ),
      );
      expect(await Future.wait([first, second]), ['new-access', 'new-access']);
      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single, {
        'grant_type': 'refresh_token',
        'client_id': 'oaiapp_test',
        'refresh_token': 'old-refresh',
        'resource': 'https://api.openai.com/v1',
      });
      expect(store.session!.accessToken, 'new-access');
      expect(store.session!.refreshToken, 'new-refresh');
    },
  );

  test(
    'an in-flight refresh cannot restore credentials after sign out',
    () async {
      store.storeSession(expiredChatGptSession(now));
      final response = Completer<Map<String, dynamic>>();
      final started = Completer<void>();
      gateway.onToken = (_) {
        started.complete();
        return response.future;
      };
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: verifier,
        now: () => now,
      );
      addTearDown(service.dispose);
      final refresh = service.accessToken();
      final failure = expectLater(refresh, throwsA(isA<LlmRequestException>()));
      await started.future;
      await service.signOut();
      response.complete(TestChatGptGateway.tokenResponse());
      await failure;
      expect(await service.isConnected, isFalse);
      expect(store.session!.accessToken, isNull);
      expect(store.session!.refreshToken, isNull);
    },
  );

  test(
    'failed revocation clears tokens and reports local-only sign out',
    () async {
      store.storeSession(expiredChatGptSession(now));
      gateway.revocationSucceeds = false;
      final service = ChatGptAuthService(credentials: store, gateway: gateway);
      addTearDown(service.dispose);
      await expectLater(
        service.signOut(),
        throwsA(isA<ChatGptRevocationUnconfirmedException>()),
      );
      expect(await service.isConnected, isFalse);
      expect(store.session!.refreshToken, isNull);
      expect(store.session!.clientId, 'oaiapp_test');
    },
  );

  test(
    'sign-in timeout closes the loopback listener and never stores a session',
    () async {
      late Uri callback;
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: verifier,
        signInTimeout: const Duration(milliseconds: 20),
        openBrowser: (uri) async {
          callback = Uri.parse(uri.queryParameters['redirect_uri']!);
          return true;
        },
      );
      addTearDown(service.dispose);
      await expectLater(
        service.signIn(),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.timeout,
          ),
        ),
      );
      expect(store.session, isNull);
      await expectLater(
        Socket.connect(callback.host, callback.port),
        throwsA(isA<SocketException>()),
      );
    },
  );
}
