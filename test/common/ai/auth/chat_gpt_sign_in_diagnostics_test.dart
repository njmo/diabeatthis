import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_sign_in_exception.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_sign_in_stage.dart';
import 'package:diabeatthis/common/analysis/ai_request_error_message.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_gpt_auth_fixtures.dart';

void main() {
  for (final stage in [
    ChatGptSignInStage.exchange,
    ChatGptSignInStage.permissions,
  ]) {
    test('reports $stage without exposing the failed response', () async {
      final store = MemoryAiCredentialStore();
      final gateway = TestChatGptGateway()
        ..onToken = (_) async {
          if (stage == ChatGptSignInStage.exchange) {
            throw StateError('secret-token-and-code');
          }
          return {...TestChatGptGateway.tokenResponse(), 'refresh_token': ''};
        };
      final service = ChatGptAuthService(
        credentials: store,
        gateway: gateway,
        identityVerifier: TestChatGptIdentityVerifier(),
        openBrowser: (uri) async {
          await completeChatGptCallback(uri);
          return true;
        },
      );
      addTearDown(service.dispose);
      try {
        await service.signIn();
        fail('Sign-in should fail');
      } on ChatGptSignInException catch (error) {
        expect(error.stage, stage);
        expect(error.cause, isNull);
        expect(error.toString(), isNot(contains('secret-token-and-code')));
        expect(
          aiRequestErrorMessage(
            lookupAppLocalizations(const Locale('pl')),
            error,
          ),
          contains('Etap:'),
        );
      }
      expect(await service.isConnected, isFalse);
      expect(store.session, isNull);
    });
  }
  test('diagnostics retain network category', () {
    const error = ChatGptSignInException(
      stage: ChatGptSignInStage.exchange,
      failure: LlmRequestFailure.network,
    );
    final lang = lookupAppLocalizations(const Locale('en'));
    expect(
      aiRequestErrorMessage(lang, error),
      contains(lang.dayAiNetworkError),
    );
    expect(
      aiRequestErrorMessage(lang, error),
      contains(lang.chatGptSignInExchange),
    );
  });
}
