import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_model_option.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/save_ai_settings_use_case.dart';
import 'package:diabeatthis/common/ai/test_ai_connection_use_case.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/regression/scripted_chat_gpt_auth_service.dart';
import '../../helpers/regression/scripted_chat_gpt_model_catalog.dart';
import '../../helpers/regression/scripted_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final action in ['signIn', 'signOut', 'models']) {
    for (final failure in [false, true]) {
      test(
        'AI settings delegates $action without persisting a provider or swallowing errors: failure=$failure',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final error = StateError('Unavailable $action');
          final connected = ScriptedRead<bool>('connected', []);
          final commands = ScriptedRead<void>(
            'auth',
            action == 'models'
                ? []
                : [
                    (
                      arguments: [action],
                      respond: () {
                        if (failure) throw error;
                      },
                    ),
                  ],
          );
          const option = AiModelOption(id: 'example-model', label: 'Example');
          final models = ScriptedRead<List<AiModelOption>>(
            'models',
            action != 'models'
                ? []
                : [
                    (
                      arguments: [],
                      respond: () {
                        if (failure) throw error;
                        return [option];
                      },
                    ),
                  ],
          );
          final container = ProviderContainer(
            overrides: [
              sharedPrefsProvider.overrideWith((ref) async => prefs),
              chatGptAuthServiceProvider.overrideWithValue(
                ScriptedChatGptAuthService(connected, commands),
              ),
              chatGptModelCatalogProvider.overrideWithValue(
                ScriptedChatGptModelCatalog(models),
              ),
              saveAiSettingsUseCaseProvider.overrideWith(
                (ref) => throw StateError('Unexpected configuration save'),
              ),
              testAiConnectionUseCaseProvider.overrideWith(
                (ref) => throw StateError('Unexpected LLM request'),
              ),
            ],
          );
          addTearDown(container.dispose);
          final before = await container.read(
            aiSettingsControllerProvider.future,
          );
          final controller = container.read(
            aiSettingsControllerProvider.notifier,
          );
          final Future<Object?> operation = switch (action) {
            'signIn' => controller.connectChatGpt(),
            'signOut' => controller.disconnectChatGpt(),
            _ => controller.chatGptModels(),
          };
          if (failure) {
            await expectLater(operation, throwsA(same(error)));
          } else {
            final result = await operation;
            if (action == 'models') expect(result, [same(option)]);
          }
          expect(
            container.read(aiSettingsControllerProvider).requireValue,
            same(before),
          );
          expect(prefs.getKeys(), isEmpty);
          connected.verifyComplete();
          commands.verifyComplete();
          models.verifyComplete();
        },
      );
    }
  }

  test(
    'disconnected ChatGPT cannot save a selection or start an LLM connection test',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final connected = ScriptedRead<bool>('connected', [
        (arguments: [], respond: () => false),
        (arguments: [], respond: () => false),
      ]);
      final commands = ScriptedRead<void>('auth', []);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          chatGptAuthServiceProvider.overrideWithValue(
            ScriptedChatGptAuthService(connected, commands),
          ),
          saveAiSettingsUseCaseProvider.overrideWith(
            (ref) => throw StateError('Unauthorized save'),
          ),
          testAiConnectionUseCaseProvider.overrideWith(
            (ref) => throw StateError('Unauthorized LLM request'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final before = await container.read(aiSettingsControllerProvider.future);
      final controller = container.read(aiSettingsControllerProvider.notifier);
      const configuration = AiConfiguration(
        provider: AiProviderKind.chatGpt,
        chatGptModel: 'example-model',
      );
      final unauthorized = throwsA(
        isA<LlmRequestException>().having(
          (e) => e.failure,
          'failure',
          LlmRequestFailure.unauthorized,
        ),
      );
      await expectLater(controller.save(configuration), unauthorized);
      await expectLater(controller.testConnection(configuration), unauthorized);
      expect(
        container.read(aiSettingsControllerProvider).requireValue,
        same(before),
      );
      expect(prefs.getKeys(), isEmpty);
      connected.verifyComplete();
      commands.verifyComplete();
    },
  );
}
