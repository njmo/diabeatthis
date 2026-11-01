import '../../../core/llm/local_llm_client.dart';

class ChatGptRevocationUnconfirmedException extends LlmRequestException {
  const ChatGptRevocationUnconfirmedException()
    : super(
        failure: LlmRequestFailure.unavailable,
        message:
            'Local ChatGPT credentials were cleared; remote revocation was not confirmed.',
      );
}

LlmRequestException chatGptAuthorizationFailure() => const LlmRequestException(
  failure: LlmRequestFailure.unauthorized,
  message: 'ChatGPT authorization could not be verified. Sign in again.',
);
