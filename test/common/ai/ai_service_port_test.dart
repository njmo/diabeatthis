import 'dart:typed_data';

import 'package:diabeatthis/common/ai/ai_client_providers.dart';
import 'package:diabeatthis/common/ai/ai_service.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/model_identified_llm_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAiService implements AiService {
  final purposes = <AiAnalysisPurpose>[];
  final imagePrompts = <String>[];
  @override
  Future<LocalLlmResponse> analyze(
    LocalLlmRequest request, {
    AiAnalysisPurpose purpose = AiAnalysisPurpose.analysis,
  }) async {
    purposes.add(purpose);
    return const LocalLlmResponse(text: 'synthetic response');
  }

  @override
  Future<Uint8List> generateImage(String prompt) async {
    imagePrompts.add(prompt);
    return Uint8List.fromList([1]);
  }

  @override
  String modelFor(AiAnalysisPurpose purpose) => 'selected-model';
}

void main() {
  test(
    'all feature adapters depend only on the shared service interface',
    () async {
      final service = RecordingAiService();
      final container = ProviderContainer(
        overrides: [aiServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      for (final provider in [
        aiAnalysisClientProvider,
        aiPhotoClientProvider,
        aiIconSuggestionClientProvider,
      ]) {
        final client = container.read(provider);
        expect(
          (await client.generate(
            const LocalLlmRequest(prompt: 'synthetic'),
          )).text,
          'synthetic response',
        );
        expect((client as ModelIdentifiedLlmClient).modelId, 'selected-model');
      }
      expect(service.purposes, [
        AiAnalysisPurpose.analysis,
        AiAnalysisPurpose.photo,
        AiAnalysisPurpose.iconSuggestion,
      ]);
      expect(
        await container.read(aiImageClientProvider).generate('synthetic image'),
        [1],
      );
      expect(service.imagePrompts, ['synthetic image']);
    },
  );
}
