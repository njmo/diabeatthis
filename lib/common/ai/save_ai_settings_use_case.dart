import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'ai_client_factory.dart';
import 'ai_configuration.dart';
import 'ai_connection_providers.dart';
import 'ai_settings_storage_keys.dart';

final saveAiSettingsUseCaseProvider = Provider<SaveAiSettingsUseCase>(
  SaveAiSettingsUseCase.new,
);

class SaveAiSettingsUseCase {
  const SaveAiSettingsUseCase(this._ref);
  final Ref _ref;

  Future<void> call(AiConfiguration normalized, {String? apiKey}) async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    final store = _ref.read(aiCredentialStoreProvider);
    final key = apiKey?.trim();
    final updateKey =
        normalized.requiresApiKey && key != null && key.isNotEmpty;
    final previousKey = updateKey
        ? await store.read(openAiApiKeyStorageKey)
        : null;
    if (updateKey) await store.write(openAiApiKeyStorageKey, key);
    try {
      if (!await prefs.setString(
        aiConfigurationStorageKey,
        jsonEncode(normalized.toJson()),
      )) {
        throw StateError('AI settings could not be saved.');
      }
    } catch (_) {
      if (updateKey) {
        if (previousKey == null) {
          await store.delete(openAiApiKeyStorageKey);
        } else {
          await store.write(openAiApiKeyStorageKey, previousKey);
        }
      }
      rethrow;
    }
  }
}
