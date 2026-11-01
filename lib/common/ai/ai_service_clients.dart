import 'dart:typed_data';

import '../../core/llm/local_llm_client.dart';
import '../../core/llm/model_identified_llm_client.dart';
import 'ai_image_client.dart';
import 'ai_service.dart';

/// Adapts existing feature ports to the common service.
class AiServiceTextClient implements LocalLlmClient, ModelIdentifiedLlmClient {
  const AiServiceTextClient(this.service, this.purpose);
  final AiService service;
  final AiAnalysisPurpose purpose;
  @override
  String get modelId => service.modelFor(purpose);
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) =>
      service.analyze(request, purpose: purpose);
}

class AiServiceImageClient implements AiImageClient {
  const AiServiceImageClient(this.service);
  final AiService service;
  @override
  Future<Uint8List> generate(String prompt) => service.generateImage(prompt);
}
