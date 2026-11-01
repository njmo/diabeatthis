import '../../core/llm/local_llm_client.dart';

class AiCapabilityUnavailableException extends LlmRequestException {
  const AiCapabilityUnavailableException()
    : super(
        failure: LlmRequestFailure.unavailable,
        message: 'The selected AI provider does not support image generation.',
      );
}
