import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
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

import '../../common/ai/helpers/recording_ai_client_factory.dart';
import '../../common/ai/helpers/recording_ai_credential_store.dart';

class LimitedDayTransport implements LocalLlmClient {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      throw const LlmOutputLimitException('{"sections":');
}

void main() {
  test(
    'day generation reserves output budget without changing shared defaults',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = RecordingAiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final container = ProviderContainer(
        overrides: [
          aiClientFactoryProvider.overrideWithValue(factory),
          aiSettingsControllerProvider.overrideWith(FirebaseTestAiSettings.new),
        ],
      );
      addTearDown(container.dispose);
      final client =
          container.read(dayAnalysisClientProvider) as LlmDayAnalysisClient;
      await client.transport.generate(
        const LocalLlmRequest(prompt: 'Synthetic budget check'),
      );
      final settings = factory.configurations.single;
      expect(factory.outputLimits.single, 8192);
      expect(factory.thinkingBudgets.single, 2048);
      final transport =
          AiClientFactory(credentials: credentials, chatGptAuth: auth).create(
                settings,
                maxOutputTokens: factory.outputLimits.single,
                thinkingBudget: factory.thinkingBudgets.single,
              )
              as FirebaseAiLlmClient;
      final config = transport.gateway.generationConfig.toJson();
      expect(settings.model, 'gemini-2.5-flash');
      expect(transport.modelName, settings.model);
      expect(client.timeout, const Duration(seconds: 60));
      expect(config['maxOutputTokens'], 8192);
      expect(config['temperature'], 0.1);
      expect(config['responseMimeType'], 'application/json');
      expect(config['thinkingConfig'], {'thinkingBudget': 2048});
      expect(const FirebaseAiLlmClient().modelName, 'gemini-2.5-flash');
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

class FirebaseTestAiSettings extends AiSettingsController {
  @override
  Future<AiConfiguration> build() async => const AiConfiguration();
}
