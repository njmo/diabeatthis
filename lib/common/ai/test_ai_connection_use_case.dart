import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/local_llm_client.dart';
import 'ai_configuration.dart';
import 'ai_connection_providers.dart';
import 'ai_service.dart';
import 'configured_ai_service.dart';

final testAiConnectionUseCaseProvider = Provider<TestAiConnectionUseCase>(
  TestAiConnectionUseCase.new,
);

class TestAiConnectionUseCase {
  const TestAiConnectionUseCase(this._ref);
  final Ref _ref;

  Future<void> call(AiConfiguration configuration, {String? apiKey}) async {
    final AiService service = ConfiguredAiService(
      configuration: Future.value(configuration),
      factory: _ref.read(aiClientFactoryProvider),
      apiKey: apiKey,
    );
    final result = await service.analyze(
      const LocalLlmRequest(
        prompt: 'Connection test. Return only this JSON object: {"ok":true}',
        timeout: Duration(seconds: 30),
      ),
      purpose: AiAnalysisPurpose.connectionTest,
    );
    final decoded = jsonDecode(result.text);
    if (decoded is! Map || decoded['ok'] != true) {
      throw const FormatException(
        'AI connection test returned an unexpected response.',
      );
    }
  }
}
