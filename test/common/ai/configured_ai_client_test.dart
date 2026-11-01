import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_client_providers.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/configured_ai_client.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/model_identified_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_llm_client.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_analysis_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_ai_client_factory.dart';
import 'helpers/recording_ai_credential_store.dart';
import 'helpers/recording_ai_test_client.dart';

void main() {
  test(
    'late configuration never starts a request after its deadline',
    () async {
      final configuration = Completer<AiConfiguration>();
      var created = false;
      final client = ConfiguredAiClient(
        configuration: configuration.future,
        createClient: (_) {
          created = true;
          return const LocalLlmUnavailableClient();
        },
      );
      await expectLater(
        client.generate(
          const LocalLlmRequest(
            prompt: 'synthetic test',
            timeout: Duration(milliseconds: 5),
          ),
        ),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.timeout,
          ),
        ),
      );
      configuration.complete(const AiConfiguration());
      await Future<void>.delayed(Duration.zero);
      expect(created, isFalse);
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'waits for settings before choosing a transport and recording its model',
    () async {
      final settings = Completer<AiConfiguration>();
      final generated = RecordingAiTestClient();
      final selected = <AiConfiguration>[];
      final client = ConfiguredAiClient(
        configuration: settings.future,
        createClient: (configuration) {
          selected.add(configuration);
          return generated;
        },
      );
      final result = client.generate(const LocalLlmRequest(prompt: 'test'));
      expect(selected, isEmpty);
      settings.complete(
        const AiConfiguration(
          provider: AiProviderKind.openAi,
          openAiModel: 'selected-model',
        ),
      );
      await result;
      expect(selected.single.provider, AiProviderKind.openAi);
      expect(client.modelId, 'selected-model');
      expect(generated.requests.single.prompt, 'test');
    },
  );

  test('configuration errors never instantiate another provider', () async {
    final settings = Completer<AiConfiguration>();
    var created = false;
    final client = ConfiguredAiClient(
      configuration: settings.future,
      createClient: (_) {
        created = true;
        return RecordingAiTestClient();
      },
    );
    final result = client.generate(const LocalLlmRequest(prompt: 'test'));
    final expectation = expectLater(result, throwsFormatException);
    settings.completeError(const FormatException('Invalid saved AI settings'));
    await expectation;
    expect(created, isFalse);
  });

  test(
    'authentication failure is propagated without provider fallback',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = AiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final client = ConfiguredAiClient(
        configuration: Future.value(
          const AiConfiguration(
            provider: AiProviderKind.openAi,
            openAiModel: 'private-model',
          ),
        ),
        createClient: factory.create,
      );
      await expectLater(
        client.generate(const LocalLlmRequest(prompt: 'test')),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.unauthorized,
          ),
        ),
      );
      expect(client.modelId, 'private-model');
      expect(credentials.reads, [openAiApiKeyStorageKey]);
    },
  );

  test(
    'factory selects Firebase, API key, and ChatGPT transports explicitly',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = AiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      const configuration = AiConfiguration(
        firebaseModel: 'firebase-model',
        openAiModel: 'api-model',
        chatGptModel: 'chatgpt-model',
      );
      final firebase = factory.create(configuration) as FirebaseAiLlmClient;
      expect(firebase.modelName, 'firebase-model');
      final api =
          factory.create(
                configuration.copyWith(provider: AiProviderKind.openAi),
                apiKey: ' draft-key ',
                maxOutputTokens: 64,
              )
              as OpenAiLlmClient;
      expect(api.modelName, 'api-model');
      expect(api.useChatGptPlan, isFalse);
      expect(api.maxOutputTokens, 64);
      expect(await api.accessToken(), 'draft-key');
      final chatGpt =
          factory.create(
                configuration.copyWith(provider: AiProviderKind.chatGpt),
              )
              as OpenAiLlmClient;
      expect(chatGpt.modelName, 'chatgpt-model');
      expect(chatGpt.useChatGptPlan, isTrue);
      expect(credentials.reads, isEmpty);
    },
  );

  test(
    'analysis draft records the actual selected model before and after provider change',
    () async {
      const initial = AiConfiguration(
        provider: AiProviderKind.openAi,
        openAiModel: 'api-selected',
        firebaseModel: 'firebase-selected',
      );
      SharedPreferences.setMockInitialValues({
        aiConfigurationStorageKey: jsonEncode(initial.toJson()),
      });
      final prefs = await SharedPreferences.getInstance();
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = RecordingAiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      factory.client.response = jsonEncode({
        'schema_version': 1,
        'language': 'pl',
        'sections': {
          for (final name in DayAnalysisResult.sectionNames)
            name: {
              'status': 'insufficient_data',
              'summary': '',
              'findings': [],
              'missing_data': ['cgm_series'],
            },
        },
      });
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          aiCredentialStoreProvider.overrideWithValue(credentials),
          chatGptAuthServiceProvider.overrideWithValue(auth),
          aiClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      final document = DayDmlDocument(text: 'DML/1\n', evidenceIds: {});
      final firstUseCase = container.read(analyzeDaySummaryUseCaseProvider);
      final first = await firstUseCase(document, language: 'pl');
      expect(first.modelId, 'api-selected');
      expect(factory.configurations.last.provider, AiProviderKind.openAi);

      await container
          .read(aiSettingsControllerProvider.notifier)
          .save(initial.copyWith(provider: AiProviderKind.firebase));
      final second = await container.read(analyzeDaySummaryUseCaseProvider)(
        document,
        language: 'pl',
      );
      expect(second.modelId, 'firebase-selected');
      expect(factory.configurations.last.provider, AiProviderKind.firebase);

      // A previously obtained use case retains the configuration of that request.
      final original = await firstUseCase(document, language: 'pl');
      expect(original.modelId, 'api-selected');
      expect(factory.configurations.last.provider, AiProviderKind.openAi);
    },
  );

  test(
    'photo and icon transports keep their existing generation budgets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = RecordingAiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          aiClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      final photo = container.read(aiPhotoClientProvider);
      await photo.generate(const LocalLlmRequest(prompt: 'photo'));
      final icon = container.read(aiIconSuggestionClientProvider);
      await icon.generate(const LocalLlmRequest(prompt: 'icon'));
      expect(factory.outputLimits, [2048, 64]);
      expect(factory.thinkingBudgets, [null, 0]);
      expect((photo as ModelIdentifiedLlmClient).modelId, 'gemini-2.5-flash');
    },
  );
}
