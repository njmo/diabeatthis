import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import '../../core/llm/local_llm_client.dart';
import 'ai_client_factory.dart';
import 'ai_configuration.dart';
import 'ai_connection_providers.dart';
import 'ai_model_option.dart';
import 'ai_provider_kind.dart';
import 'ai_settings_storage_keys.dart';
import 'save_ai_settings_use_case.dart';
import 'test_ai_connection_use_case.dart';

export 'ai_settings_storage_keys.dart' show aiConfigurationStorageKey;

final aiSettingsControllerProvider =
    AsyncNotifierProvider<AiSettingsController, AiConfiguration>(
      AiSettingsController.new,
    );

class AiSettingsController extends AsyncNotifier<AiConfiguration> {
  @override
  Future<AiConfiguration> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final raw = prefs.getString(aiConfigurationStorageKey);
    return raw == null
        ? const AiConfiguration()
        : AiConfiguration.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> hasApiKey() async =>
      (await ref.read(aiCredentialStoreProvider).read(openAiApiKeyStorageKey))
          ?.trim()
          .isNotEmpty ==
      true;

  Future<bool> isChatGptConnected() =>
      ref.read(chatGptAuthServiceProvider).isConnected;

  Future<void> connectChatGpt() =>
      ref.read(chatGptAuthServiceProvider).signIn();

  Future<void> disconnectChatGpt() =>
      ref.read(chatGptAuthServiceProvider).signOut();

  Future<void> deleteApiKey() =>
      ref.read(aiCredentialStoreProvider).delete(openAiApiKeyStorageKey);

  Future<List<AiModelOption>> chatGptModels() =>
      ref.read(chatGptModelCatalogProvider).load();

  Future<void> save(AiConfiguration configuration, {String? apiKey}) async {
    final normalized = AiConfiguration.fromJson(configuration.toJson());
    await _validate(normalized, apiKey);
    await ref.read(saveAiSettingsUseCaseProvider)(normalized, apiKey: apiKey);
    if (ref.mounted) state = AsyncData(normalized);
  }

  Future<void> testConnection(
    AiConfiguration configuration, {
    String? apiKey,
  }) async {
    final normalized = AiConfiguration.fromJson(configuration.toJson());
    await _validate(normalized, apiKey);
    await ref.read(testAiConnectionUseCaseProvider)(normalized, apiKey: apiKey);
  }

  Future<void> _validate(AiConfiguration configuration, String? apiKey) async {
    if (configuration.model.trim().isEmpty) {
      throw ArgumentError('An AI model is required.');
    }
    if (configuration.requiresApiKey &&
        (apiKey == null || apiKey.trim().isEmpty) &&
        !await hasApiKey()) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'An OpenAI API key is required.',
      );
    }
    if (configuration.provider == AiProviderKind.chatGpt &&
        !await isChatGptConnected()) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'Sign in with ChatGPT first.',
      );
    }
  }
}
