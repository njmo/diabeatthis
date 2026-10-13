import 'dart:async';

import '../../core/llm/local_llm_client.dart';
import '../l10n/language.dart';

String aiRequestErrorMessage(AppLocalizations lang, Object? error) {
  if (error is TimeoutException) return lang.dayAiTimeout;
  if (error is LlmRequestException) {
    return switch (error.failure) {
      LlmRequestFailure.network => lang.dayAiNetworkError,
      LlmRequestFailure.unauthorized => lang.dayAiUnauthorized,
      LlmRequestFailure.quotaExceeded => lang.dayAiQuotaExceeded,
      LlmRequestFailure.timeout => lang.dayAiTimeout,
      LlmRequestFailure.unavailable => lang.dayAiUnavailable,
    };
  }
  return lang.dayAiFailed;
}
