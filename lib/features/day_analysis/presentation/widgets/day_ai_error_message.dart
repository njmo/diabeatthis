import 'dart:async';

import '../../../../common/l10n/language.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../domain/models/day_analysis_invalid_response.dart';

String dayAiErrorMessage(AppLocalizations lang, Object? error) {
  if (error is DayAnalysisInvalidResponse && error.tokenLimitReached) {
    return lang.dayAiOutputLimit;
  }
  if (error is FormatException) return lang.dayAiInvalidResponse;
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
