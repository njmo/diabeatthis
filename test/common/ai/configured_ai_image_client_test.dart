import 'dart:async';

import 'package:diabeatthis/common/ai/ai_capability_unavailable_exception.dart';
import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_client_providers.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/configured_ai_image_client.dart';
import 'package:diabeatthis/core/llm/firebase_ai_image_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/core/llm/openai_image_client.dart';
import 'package:diabeatthis/core/llm/providers/firebase_ai_llm_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/counting_chat_gpt_auth_service.dart';
import 'helpers/fixed_ai_image_settings.dart';
import 'helpers/recording_ai_client_factory.dart';
import 'helpers/recording_ai_credential_store.dart';
import 'helpers/recording_ai_image_client.dart';

void main() {
  test(
    'waits for the selected image provider and passes the remaining deadline',
    () async {
      final settings = Completer<AiConfiguration>();
      final generated = RecordingAiImageClient();
      final selected = <AiConfiguration>[];
      final deadlines = <Duration>[];
      const budget = Duration(seconds: 2);
      final client = ConfiguredAiImageClient(
        configuration: settings.future,
        timeout: budget,
        createClient: (configuration, {required timeout}) {
          selected.add(configuration);
          deadlines.add(timeout);
          return generated;
        },
      );
      final result = client.generate('Synthetic apple');
      expect(selected, isEmpty);
      expect(generated.prompts, isEmpty);
      const configuration = AiConfiguration(provider: AiProviderKind.openAi);
      settings.complete(configuration);
      expect(await result, generated.bytes);
      expect(selected, [configuration]);
      expect(deadlines.single, greaterThan(Duration.zero));
      expect(deadlines.single, lessThanOrEqualTo(budget));
      expect(generated.prompts, ['Synthetic apple']);
    },
  );

  test(
    'configuration failure creates no image client and preserves the error',
    () async {
      final settings = Completer<AiConfiguration>();
      var creations = 0;
      const failure = FormatException('Invalid saved AI provider');
      final client = ConfiguredAiImageClient(
        configuration: settings.future,
        createClient: (_, {required timeout}) {
          creations++;
          return RecordingAiImageClient();
        },
      );
      final result = client.generate('Synthetic apple');
      final expectation = expectLater(result, throwsA(same(failure)));
      settings.completeError(failure);
      await expectation;
      expect(creations, 0);
    },
  );

  test(
    'late configuration cannot start image generation after its timeout',
    () async {
      final settings = Completer<AiConfiguration>();
      var creations = 0;
      final generated = RecordingAiImageClient();
      final client = ConfiguredAiImageClient(
        configuration: settings.future,
        timeout: const Duration(milliseconds: 5),
        createClient: (_, {required timeout}) {
          creations++;
          return generated;
        },
      );
      await expectLater(
        client.generate('Synthetic apple'),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.timeout,
          ),
        ),
      );
      settings.complete(const AiConfiguration(provider: AiProviderKind.openAi));
      await Future<void>.delayed(Duration.zero);
      expect(creations, 0);
      expect(generated.prompts, isEmpty);
    },
  );

  test('a selected provider failure is not retried through Firebase', () async {
    const failure = LlmRequestException(
      failure: LlmRequestFailure.quotaExceeded,
      message: 'Quota exhausted',
    );
    final generated = RecordingAiImageClient()..error = failure;
    final selected = <AiProviderKind>[];
    final client = ConfiguredAiImageClient(
      configuration: Future.value(
        const AiConfiguration(provider: AiProviderKind.openAi),
      ),
      createClient: (configuration, {required timeout}) {
        selected.add(configuration.provider);
        return generated;
      },
    );
    await expectLater(
      client.generate('Synthetic apple'),
      throwsA(same(failure)),
    );
    expect(selected, [AiProviderKind.openAi]);
    expect(generated.prompts, ['Synthetic apple']);
  });

  test(
    'factory chooses image transports without accessing credentials early',
    () {
      final credentials = RecordingAiCredentialStore();
      final auth = CountingChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = AiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      const deadline = Duration(seconds: 17);
      final firebase = factory.createImageClient(
        const AiConfiguration(),
        timeout: deadline,
      );
      final openAi = factory.createImageClient(
        const AiConfiguration(provider: AiProviderKind.openAi),
        timeout: deadline,
      );
      expect(
        firebase,
        isA<FirebaseAiImageClient>().having(
          (client) => client.timeout,
          'deadline',
          deadline,
        ),
      );
      expect(
        openAi,
        isA<OpenAiImageClient>().having(
          (client) => client.timeout,
          'deadline',
          deadline,
        ),
      );
      expect(credentials.reads, isEmpty);
      expect(auth.accessTokenCalls, 0);
    },
  );

  test('ChatGPT images fail locally without API-key or OAuth access', () async {
    final credentials = RecordingAiCredentialStore()
      ..values[openAiApiKeyStorageKey] = 'an-existing-api-key';
    final auth = CountingChatGptAuthService(credentials: credentials);
    addTearDown(auth.dispose);
    final factory = AiClientFactory(
      credentials: credentials,
      chatGptAuth: auth,
    );
    final container = ProviderContainer(
      overrides: [
        aiSettingsControllerProvider.overrideWith(
          () => FixedAiImageSettings(
            const AiConfiguration(provider: AiProviderKind.chatGpt),
          ),
        ),
        aiClientFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(aiImageClientProvider).generate('Synthetic apple'),
      throwsA(isA<AiCapabilityUnavailableException>()),
    );
    expect(credentials.reads, isEmpty);
    expect(credentials.writes, isEmpty);
    expect(auth.accessTokenCalls, 0);
  });

  test(
    'central image provider uses OpenAI credentials and never Firebase on auth failure',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = CountingChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = AiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final container = ProviderContainer(
        overrides: [
          aiSettingsControllerProvider.overrideWith(
            () => FixedAiImageSettings(
              const AiConfiguration(provider: AiProviderKind.openAi),
            ),
          ),
          aiClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(aiImageClientProvider).generate('Synthetic apple'),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.unauthorized,
          ),
        ),
      );
      expect(credentials.reads, [openAiApiKeyStorageKey]);
      expect(auth.accessTokenCalls, 0);
    },
  );

  test(
    'legacy Firebase-named provider obeys the central selected photo transport',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = CountingChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = RecordingAiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final container = ProviderContainer(
        overrides: [
          aiSettingsControllerProvider.overrideWith(
            () => FixedAiImageSettings(
              const AiConfiguration(
                provider: AiProviderKind.openAi,
                openAiModel: 'selected-photo-model',
              ),
            ),
          ),
          aiClientFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        firebaseAiLlmClientProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final legacy = container.read(firebaseAiLlmClientProvider);
      expect(legacy, same(container.read(aiPhotoClientProvider)));
      await legacy.generate(
        const LocalLlmRequest(prompt: 'Synthetic photo request'),
      );
      expect(factory.configurations.single.provider, AiProviderKind.openAi);
      expect(factory.configurations.single.openAiModel, 'selected-photo-model');
      expect(factory.client.requests.single.prompt, 'Synthetic photo request');
      expect(factory.outputLimits, [2048]);
      expect(factory.thinkingBudgets, [null]);
    },
  );
}
