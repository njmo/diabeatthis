import 'dart:typed_data';

import '../../core/llm/local_llm_client.dart';

enum AiAnalysisPurpose { analysis, photo, iconSuggestion, connectionTest }

abstract interface class AiService {
  Future<LocalLlmResponse> analyze(
    LocalLlmRequest request, {
    AiAnalysisPurpose purpose = AiAnalysisPurpose.analysis,
  });
  String modelFor(AiAnalysisPurpose purpose);
  Future<Uint8List> generateImage(String prompt);
}
