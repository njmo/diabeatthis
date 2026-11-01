import 'dart:convert';

import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/recording_ai_client_factory.dart';
import 'helpers/recording_ai_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late RecordingAiCredentialStore credentials;
  late ChatGptAuthService auth;
  late RecordingAiClientFactory factory;
  late ProviderContainer container;

  ProviderContainer createContainer() => ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWith((ref) async => preferences),
      aiCredentialStoreProvider.overrideWithValue(credentials),
      chatGptAuthServiceProvider.overrideWithValue(auth),
      aiClientFactoryProvider.overrideWithValue(factory),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    credentials = RecordingAiCredentialStore();
    auth = ChatGptAuthService(credentials: credentials);
    factory = RecordingAiClientFactory(
      credentials: credentials,
      chatGptAuth: auth,
    );
    container = createContainer();
    await container.read(aiSettingsControllerProvider.future);
  });

  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  test(
    'default Firebase settings do not read credentials or make a request',
    () async {
      final configuration = await container.read(
        aiSettingsControllerProvider.future,
      );
      expect(configuration.provider, AiProviderKind.firebase);
      expect(configuration.model, 'gemini-2.5-flash');
      expect(credentials.reads, isEmpty);
      expect(credentials.writes, isEmpty);
      expect(factory.configurations, isEmpty);

      await container
          .read(aiSettingsControllerProvider.notifier)
          .save(configuration);
      expect(credentials.reads, isEmpty);
      expect(credentials.writes, isEmpty);
    },
  );

  test(
    'switches provider and persists separate normalized model choices',
    () async {
      final controller = container.read(aiSettingsControllerProvider.notifier);
      const original = AiConfiguration(
        firebaseModel: ' gemini-custom ',
        openAiModel: ' openai-custom ',
        chatGptModel: ' chatgpt-custom ',
      );
      await controller.save(original);
      await controller.save(
        original.copyWith(provider: AiProviderKind.openAi),
        apiKey: '  private-key  ',
      );
      final saved = container.read(aiSettingsControllerProvider).requireValue;
      expect(saved.provider, AiProviderKind.openAi);
      expect(saved.model, 'openai-custom');
      expect(saved.firebaseModel, 'gemini-custom');
      expect(saved.chatGptModel, 'chatgpt-custom');
      expect(credentials.values[openAiApiKeyStorageKey], 'private-key');
      expect(
        preferences.getString(aiConfigurationStorageKey),
        isNot(contains('private-key')),
      );

      container.dispose();
      container = createContainer();
      final restored = await container.read(
        aiSettingsControllerProvider.future,
      );
      expect(restored.toJson(), saved.toJson());
      await container
          .read(aiSettingsControllerProvider.notifier)
          .save(restored.copyWith(provider: AiProviderKind.firebase));
      final switched = container
          .read(aiSettingsControllerProvider)
          .requireValue;
      expect(switched.model, 'gemini-custom');
      expect(switched.openAiModel, 'openai-custom');
      expect(switched.chatGptModel, 'chatgpt-custom');
    },
  );

  test(
    'tests draft settings with a synthetic prompt without saving key or provider',
    () async {
      final controller = container.read(aiSettingsControllerProvider.notifier);
      const saved = AiConfiguration(firebaseModel: 'saved-firebase');
      await controller.save(saved);
      final storedBefore = preferences.getString(aiConfigurationStorageKey);
      final draft = saved.copyWith(
        provider: AiProviderKind.openAi,
        openAiModel: 'draft-model',
      );

      await controller.testConnection(draft, apiKey: 'draft-private-key');

      expect(factory.configurations.single.toJson(), draft.toJson());
      expect(factory.keys.single, 'draft-private-key');
      expect(factory.outputLimits.single, 512);
      expect(factory.thinkingBudgets.single, 0);
      final request = factory.client.requests.single;
      expect(
        request.prompt,
        'Connection test. Return only this JSON object: {"ok":true}',
      );
      expect(
        request.timeout,
        allOf(
          greaterThan(Duration.zero),
          lessThanOrEqualTo(const Duration(seconds: 30)),
        ),
      );
      expect(request.imagePaths, isEmpty);
      expect(credentials.writes, isEmpty);
      expect(credentials.values, isEmpty);
      expect(preferences.getString(aiConfigurationStorageKey), storedBefore);
      expect(
        container.read(aiSettingsControllerProvider).requireValue.toJson(),
        saved.toJson(),
      );
    },
  );

  test(
    'failed connection test keeps persisted configuration unchanged',
    () async {
      factory.client.error = const LlmRequestException(
        failure: LlmRequestFailure.network,
        message: 'Unavailable',
      );
      await expectLater(
        container
            .read(aiSettingsControllerProvider.notifier)
            .testConnection(
              const AiConfiguration(provider: AiProviderKind.openAi),
              apiKey: 'draft-key',
            ),
        throwsA(isA<LlmRequestException>()),
      );
      expect(preferences.getString(aiConfigurationStorageKey), isNull);
      expect(credentials.values, isEmpty);
      expect(
        container.read(aiSettingsControllerProvider).requireValue.provider,
        AiProviderKind.firebase,
      );
    },
  );

  test(
    'connection test rejects a completed response with the wrong payload',
    () async {
      factory.client.response = '{"ok":false}';
      await expectLater(
        container
            .read(aiSettingsControllerProvider.notifier)
            .testConnection(const AiConfiguration()),
        throwsFormatException,
      );
      expect(preferences.getString(aiConfigurationStorageKey), isNull);
    },
  );

  test('blank key preserves existing secret and removal is explicit', () async {
    final controller = container.read(aiSettingsControllerProvider.notifier);
    const configuration = AiConfiguration(provider: AiProviderKind.openAi);
    await controller.save(configuration, apiKey: 'saved-key');
    final writesBefore = credentials.writes.length;
    await controller.save(
      configuration.copyWith(openAiModel: 'other-model'),
      apiKey: '   ',
    );
    expect(credentials.values[openAiApiKeyStorageKey], 'saved-key');
    expect(credentials.writes.length, writesBefore);
    expect(await controller.hasApiKey(), isTrue);
    await controller.deleteApiKey();
    expect(await controller.hasApiKey(), isFalse);
    expect(credentials.deletions, [openAiApiKeyStorageKey]);
    expect(
      container.read(aiSettingsControllerProvider).requireValue.provider,
      AiProviderKind.openAi,
    );
    await expectLater(
      controller.testConnection(configuration),
      throwsA(
        isA<LlmRequestException>().having(
          (error) => error.failure,
          'failure',
          LlmRequestFailure.unauthorized,
        ),
      ),
    );
    expect(factory.configurations, isEmpty);
  });

  test(
    'missing OpenAI credentials cannot save a selection or run a test',
    () async {
      final controller = container.read(aiSettingsControllerProvider.notifier);
      const configuration = AiConfiguration(provider: AiProviderKind.openAi);
      await expectLater(
        controller.save(configuration),
        throwsA(isA<LlmRequestException>()),
      );
      await expectLater(
        controller.testConnection(configuration),
        throwsA(isA<LlmRequestException>()),
      );
      expect(preferences.getString(aiConfigurationStorageKey), isNull);
      expect(factory.configurations, isEmpty);
      expect(
        container.read(aiSettingsControllerProvider).requireValue.provider,
        AiProviderKind.firebase,
      );
    },
  );

  test(
    'credential-store failure never activates a Firebase fallback',
    () async {
      credentials.readError = StateError('Secure storage unavailable');
      final controller = container.read(aiSettingsControllerProvider.notifier);
      await expectLater(
        controller.testConnection(
          const AiConfiguration(provider: AiProviderKind.openAi),
        ),
        throwsStateError,
      );
      expect(factory.configurations, isEmpty);
      expect(preferences.getString(aiConfigurationStorageKey), isNull);
    },
  );

  test(
    'invalid persisted configuration is surfaced rather than defaulted to Firebase',
    () async {
      await preferences.setString(
        aiConfigurationStorageKey,
        jsonEncode({'provider': 'unknown'}),
      );
      container.dispose();
      container = createContainer();
      await expectLater(
        container.read(aiSettingsControllerProvider.future),
        throwsFormatException,
      );
      expect(credentials.reads, isEmpty);
      expect(factory.configurations, isEmpty);
    },
  );
}
