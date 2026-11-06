import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_callback_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android return uses a fixed credential-free intent with an exact CSP hash',
    () {
      const page = ChatGptCallbackPage(
        title: 'Return',
        message: 'Finish verification in the app',
        returnToAppLabel: 'Back to app',
      );
      expect(page.html, contains(ChatGptCallbackPage.returnIntent));
      expect(
        page.html,
        contains('<script>${ChatGptCallbackPage.returnScript}</script>'),
      );
      final hash = base64.encode(
        sha256.convert(utf8.encode(ChatGptCallbackPage.returnScript)).bytes,
      );
      expect(
        page.responseSecurityPolicy,
        contains("script-src 'sha256-$hash'"),
      );
      expect(
        page.responseSecurityPolicy,
        isNot(contains("script-src 'unsafe-inline'")),
      );
      expect(page.html, isNot(contains('access_token')));
      expect(page.html, isNot(contains('code=')));
      expect(page.html, isNot(contains('state=')));
    },
  );
  test('platforms without app return retain the inert callback document', () {
    const page = ChatGptCallbackPage(
      title: 'Return',
      message: 'Return manually',
    );
    expect(page.html, isNot(contains('<script')));
    expect(
      page.responseSecurityPolicy,
      ChatGptCallbackPage.contentSecurityPolicy,
    );
  });
}
