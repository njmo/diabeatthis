import 'dart:typed_data';

import '../../core/llm/local_llm_client.dart';
import 'ai_client_factory.dart';
import 'ai_configuration.dart';
import 'ai_provider_kind.dart';
import 'ai_service.dart';
import 'configured_ai_client.dart';
import 'configured_ai_image_client.dart';

/// Resolves each request from one settings snapshot, without provider fallback.
class ConfiguredAiService implements AiService {
  ConfiguredAiService({
    required Future<AiConfiguration> configuration,
    required AiClientFactory factory,
    String? apiKey,
  }) {
    for (final purpose in AiAnalysisPurpose.values) {
      LocalLlmClient create(
        AiConfiguration settings, {
        int? outputTokenLimit,
      }) => factory.create(
        settings,
        apiKey: apiKey,
        maxOutputTokens:
            outputTokenLimit ??
            switch (purpose) {
              AiAnalysisPurpose.analysis => 8192,
              AiAnalysisPurpose.photo => 2048,
              AiAnalysisPurpose.iconSuggestion =>
                settings.provider == AiProviderKind.firebase ? 64 : 2048,
              AiAnalysisPurpose.connectionTest => 512,
            },
        thinkingBudget: switch (purpose) {
          AiAnalysisPurpose.analysis => 2048,
          AiAnalysisPurpose.photo => null,
          AiAnalysisPurpose.iconSuggestion ||
          AiAnalysisPurpose.connectionTest => 0,
        },
      );
      _clients[purpose] = ConfiguredAiClient(
        configuration: configuration,
        createClient: create,
        createClientForRequest: (settings, request) =>
            create(settings, outputTokenLimit: request.maxOutputTokens),
      );
    }
    _images = ConfiguredAiImageClient(
      configuration: configuration,
      createClient: factory.createImageClient,
    );
  }

  final _clients = <AiAnalysisPurpose, ConfiguredAiClient>{};
  late final ConfiguredAiImageClient _images;

  @override
  Future<LocalLlmResponse> analyze(
    LocalLlmRequest request, {
    AiAnalysisPurpose purpose = AiAnalysisPurpose.analysis,
  }) => _clients[purpose]!.generate(request);
  @override
  String modelFor(AiAnalysisPurpose purpose) => _clients[purpose]!.modelId;
  @override
  Future<Uint8List> generateImage(String prompt) => _images.generate(prompt);
}
