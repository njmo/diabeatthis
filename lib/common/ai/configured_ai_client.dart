import 'dart:async';

import '../../core/llm/local_llm_client.dart';
import '../../core/llm/model_identified_llm_client.dart';
import 'ai_configuration.dart';

/// Captures one settings snapshot, including while preferences are still loading.
/// A request never falls back to another provider if loading or authentication fails.
class ConfiguredAiClient implements LocalLlmClient, ModelIdentifiedLlmClient {
  ConfiguredAiClient({
    required this.configuration,
    required this.createClient,
    this.createClientForRequest,
  });

  final Future<AiConfiguration> configuration;
  final LocalLlmClient Function(AiConfiguration) createClient;
  final LocalLlmClient Function(AiConfiguration, LocalLlmRequest)?
  createClientForRequest;
  String? _modelId;

  @override
  String get modelId => _modelId ?? 'pending';

  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async {
    final elapsed = Stopwatch()..start();
    final timeout = request.timeout;
    try {
      final settings = timeout == null
          ? await configuration
          : await configuration.timeout(timeout);
      final remaining = timeout == null ? null : timeout - elapsed.elapsed;
      if (remaining != null && remaining <= Duration.zero) {
        throw TimeoutException('AI configuration timed out.');
      }
      _modelId = settings.model;
      final client =
          createClientForRequest?.call(settings, request) ??
          createClient(settings);
      return await client.generate(
        LocalLlmRequest(
          prompt: request.prompt,
          imagePaths: request.imagePaths,
          timeout: remaining,
          maxOutputTokens: request.maxOutputTokens,
          responseJsonSchema: request.responseJsonSchema,
        ),
      );
    } on TimeoutException {
      throw const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'AI request timed out.',
      );
    }
  }
}
