import 'local_llm_client.dart';

/// Never includes response bodies, prompts, credentials, or provider messages.
LlmRequestException openAiRequestException({int? statusCode, String? code}) {
  final failure = switch (statusCode) {
    401 || 403 => LlmRequestFailure.unauthorized,
    408 || 504 => LlmRequestFailure.timeout,
    429 => LlmRequestFailure.quotaExceeded,
    _ => switch (code) {
      'invalid_api_key' ||
      'invalid_token' ||
      'token_expired' ||
      'permission_denied' ||
      'subscription_sharing_user_not_eligible' =>
        LlmRequestFailure.unauthorized,
      'rate_limit_exceeded' ||
      'insufficient_quota' ||
      'credit_balance_exhausted' => LlmRequestFailure.quotaExceeded,
      'timeout' => LlmRequestFailure.timeout,
      _ => LlmRequestFailure.unavailable,
    },
  };
  return LlmRequestException(
    failure: failure,
    message: 'OpenAI request failed.',
  );
}
