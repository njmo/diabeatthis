import 'dart:async';

import '../../core/llm/local_llm_client.dart';
import '../ai/auth/chat_gpt_sign_in_exception.dart';
import '../ai/auth/chat_gpt_sign_in_stage.dart';
import '../l10n/language.dart';

String aiRequestErrorMessage(AppLocalizations lang, Object? error) {
  if (error is TimeoutException) return lang.dayAiTimeout;
  if (error is LlmRequestException) {
    final message = switch (error.failure) {
      LlmRequestFailure.network => lang.dayAiNetworkError,
      LlmRequestFailure.unauthorized => lang.dayAiUnauthorized,
      LlmRequestFailure.quotaExceeded => lang.dayAiQuotaExceeded,
      LlmRequestFailure.timeout => lang.dayAiTimeout,
      LlmRequestFailure.unavailable => lang.dayAiUnavailable,
    };
    if (error is ChatGptSignInException) {
      final stage = switch (error.stage) {
        ChatGptSignInStage.credentials => lang.chatGptSignInCredentials,
        ChatGptSignInStage.discovery => lang.chatGptSignInDiscovery,
        ChatGptSignInStage.browser => lang.chatGptSignInBrowser,
        ChatGptSignInStage.callback => lang.chatGptSignInCallback,
        ChatGptSignInStage.exchange => lang.chatGptSignInExchange,
        ChatGptSignInStage.verification => lang.chatGptSignInVerification,
        ChatGptSignInStage.permissions => lang.chatGptSignInPermissions,
        ChatGptSignInStage.storage => lang.chatGptSignInStorage,
      };
      return lang.chatGptSignInFailedAt(stage, message);
    }
    return message;
  }
  return lang.dayAiFailed;
}
