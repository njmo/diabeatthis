import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/firebase_ai_response.dart';
import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/day_analysis/data/clients/llm_day_analysis_client.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_invalid_response.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class LimitedDayTransport implements LocalLlmClient {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      throw const LlmOutputLimitException('{"sections":');
}

void main() {
  test(
    'day generation reserves output budget without changing shared defaults',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client =
          container.read(dayAnalysisClientProvider) as LlmDayAnalysisClient;
      final transport = client.transport as FirebaseAiLlmClient;
      final config = transport.gateway.generationConfig.toJson();
      expect(config['maxOutputTokens'], 8192);
      expect(config['thinkingConfig'], containsPair('thinkingBudget', 2048));
      expect(const FirebaseAiGenerateContentGateway().maxOutputTokens, 2048);
      expect(const FirebaseAiGenerateContentGateway().thinkingBudget, isNull);
    },
  );

  test(
    'MAX_TOKENS preserves raw output and rejects even syntactically valid JSON',
    () {
      for (final text in ['{"sections":', '{}', '']) {
        final response = GenerateContentResponse([
          Candidate(
            Content.text(text),
            null,
            null,
            FinishReason.maxTokens,
            null,
          ),
        ], null);
        expect(
          () => readFirebaseAiResponse(response),
          throwsA(
            isA<LlmOutputLimitException>().having(
              (e) => e.response,
              'partial output',
              text,
            ),
          ),
        );
      }
      expect(
        readFirebaseAiResponse(
          GenerateContentResponse([
            Candidate(Content.text('{}'), null, null, FinishReason.stop, null),
          ], null),
        ),
        '{}',
      );
    },
  );

  test(
    'day adapter retains partial output and exposes token limit to the UI',
    () async {
      final client = LlmDayAnalysisClient(
        transport: LimitedDayTransport(),
        modelId: 'test',
      );
      await expectLater(
        client.analyze(
          DayDmlDocument(text: 'DML/1', evidenceIds: {}),
          language: 'pl',
        ),
        throwsA(
          isA<DayAnalysisInvalidResponse>()
              .having((e) => e.tokenLimitReached, 'token limit', isTrue)
              .having((e) => e.response, 'partial output', '{"sections":'),
        ),
      );
    },
  );
}
