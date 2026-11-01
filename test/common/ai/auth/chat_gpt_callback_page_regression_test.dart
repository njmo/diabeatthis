import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_callback_page.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_loopback_callback.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_gpt_auth_fixtures.dart';

void main() {
  const page = ChatGptCallbackPage(
    title: 'Wróć do Diabeatthis',
    message: 'Wróć do aplikacji, aby dokończyć łączenie.',
  );

  test(
    'browser receives a localized document and sign-in finishes with keep-alive',
    () async {
      final browser = HttpClient();
      addTearDown(() => browser.close(force: true));
      final store = MemoryAiCredentialStore();
      final gateway = TestChatGptGateway();
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: TestChatGptIdentityVerifier(),
        callbackPage: () => page,
        openBrowser: (authorization) async {
          final uri = Uri.parse(authorization.queryParameters['redirect_uri']!)
              .replace(
                queryParameters: {
                  'state': authorization.queryParameters['state']!,
                  'code': 'sensitive-authorization-code',
                  'client_id': 'oaiapp_test',
                },
              );
          final response = await (await browser.getUrl(uri)).close();
          final html = await utf8.decoder.bind(response).join();
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers.contentType?.mimeType, 'text/html');
          expect(response.headers.value('cache-control'), 'no-store');
          expect(response.headers.value('referrer-policy'), 'no-referrer');
          expect(
            response.headers.value('content-security-policy'),
            ChatGptCallbackPage.contentSecurityPolicy,
          );
          expect(html, contains(page.title));
          expect(html, contains(page.message));
          for (final secret in [
            'sensitive-authorization-code',
            'oaiapp_test',
            authorization.queryParameters['state']!,
            authorization.queryParameters['nonce']!,
            uri.toString(),
          ]) {
            expect(html, isNot(contains(secret)));
          }
          expect(html, isNot(contains('<script')));
          expect(html, isNot(contains('<img')));
          return true;
        },
      );
      addTearDown(service.dispose);
      // Keep the browser connection alive while the server shuts down.
      await service.signIn().timeout(const Duration(seconds: 2));
      expect(await service.isConnected, isTrue);
      expect(gateway.requests, hasLength(1));
    },
  );

  test(
    'denied consent also ends the browser navigation without claiming success',
    () async {
      final browser = HttpClient();
      addTearDown(() => browser.close(force: true));
      final gateway = TestChatGptGateway();
      final store = MemoryAiCredentialStore();
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        callbackPage: () => page,
        openBrowser: (authorization) async {
          final uri = Uri.parse(authorization.queryParameters['redirect_uri']!)
              .replace(
                queryParameters: {
                  'state': authorization.queryParameters['state']!,
                  'error': 'access_denied',
                  'error_description': 'sensitive-provider-diagnostic',
                },
              );
          final response = await (await browser.getUrl(uri)).close();
          final html = await utf8.decoder.bind(response).join();
          expect(response.statusCode, HttpStatus.ok);
          expect(html, contains(page.message));
          expect(html, isNot(contains('sensitive-provider-diagnostic')));
          return true;
        },
      );
      addTearDown(service.dispose);
      await expectLater(
        service.signIn().timeout(const Duration(seconds: 2)),
        throwsA(isA<LlmRequestException>()),
      );
      expect(gateway.requests, isEmpty);
      expect(await service.isConnected, isFalse);
    },
  );

  test(
    'missing state never renders the page or consumes the valid callback',
    () async {
      final callback = await ChatGptLoopbackCallback.start(
        'expected-state',
        page: page,
      );
      addTearDown(callback.close);
      final browser = HttpClient();
      addTearDown(() => browser.close(force: true));
      final rejected = await (await browser.getUrl(
        callback.redirectUri,
      )).close();
      final rejectedBody = await utf8.decoder.bind(rejected).join();
      expect(rejected.statusCode, HttpStatus.badRequest);
      expect(rejectedBody, isNot(contains(page.title)));
      final valid = callback.redirectUri.replace(
        queryParameters: {'state': 'expected-state', 'code': 'code'},
      );
      final accepted = await (await browser.getUrl(valid)).close();
      await accepted.drain<void>();
      expect(accepted.statusCode, HttpStatus.ok);
      expect((await callback.result).queryParameters['code'], 'code');
      await callback.close().timeout(const Duration(seconds: 2));
    },
  );

  test('localized content is escaped instead of interpreted as HTML', () {
    const escaped = ChatGptCallbackPage(
      title: '<script>alert(1)</script> & title',
      message: '<img src="https://example.com/">',
    );
    expect(
      escaped.html,
      contains('&lt;script&gt;alert(1)&lt;/script&gt; &amp; title'),
    );
    expect(escaped.html, contains('&lt;img src="https://example.com/"&gt;'));
    expect(escaped.html, isNot(contains('<script>')));
    expect(escaped.html, isNot(contains('<img ')));
  });

  test(
    'callback content factory reads the current locale for each sign-in',
    () async {
      var currentPage = page;
      final titles = <String>[];
      final browser = HttpClient();
      addTearDown(() => browser.close(force: true));
      final service = ChatGptAuthService(
        credentials: MemoryAiCredentialStore(),
        gateway: TestChatGptGateway(),
        identityVerifier: TestChatGptIdentityVerifier(),
        callbackPage: () {
          titles.add(currentPage.title);
          return currentPage;
        },
        openBrowser: (authorization) async {
          final uri = Uri.parse(authorization.queryParameters['redirect_uri']!)
              .replace(
                queryParameters: {
                  'state': authorization.queryParameters['state']!,
                  'code': 'code',
                  'client_id': 'oaiapp_test',
                },
              );
          final response = await (await browser.getUrl(uri)).close();
          final html = await utf8.decoder.bind(response).join();
          expect(html, contains(currentPage.title));
          return true;
        },
      );
      addTearDown(service.dispose);
      await service.signIn();
      currentPage = const ChatGptCallbackPage(
        title: 'Return to Diabeatthis',
        message: 'Return to the app to finish connecting.',
      );
      await service.signIn();
      expect(titles, ['Wróć do Diabeatthis', 'Return to Diabeatthis']);
    },
  );
}
