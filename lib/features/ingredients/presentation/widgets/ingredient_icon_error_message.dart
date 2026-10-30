import 'dart:async';

import '../../../../common/l10n/language.dart';
import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';

String ingredientIconErrorMessage(AppLocalizations language, Object? error) {
  if (error is LlmRequestException) {
    return switch (error.failure) {
      LlmRequestFailure.network => language.ingredientAiNetworkError,
      LlmRequestFailure.unauthorized => language.ingredientAiUnauthorized,
      LlmRequestFailure.quotaExceeded => language.ingredientAiQuotaExceeded,
      LlmRequestFailure.timeout => language.ingredientAiTimeout,
      LlmRequestFailure.unavailable => language.ingredientAiUnavailable,
    };
  }
  if (error is TimeoutException) return language.ingredientAiTimeout;
  if (error is LlmOutputLimitException) {
    return language.ingredientIconOutputLimit;
  }
  if (error is FormatException) return language.ingredientIconInvalidResponse;
  return error == null
      ? language.ingredientIconSuggestionFailed
      : language.ingredientAiUnavailable;
}
