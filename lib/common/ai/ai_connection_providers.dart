import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/language.dart';
import 'ai_client_factory.dart';
import 'ai_credential_store.dart';
import 'auth/chat_gpt_auth_service.dart';
import 'auth/chat_gpt_callback_page.dart';
import 'chat_gpt_model_catalog.dart';
import 'secure_ai_credential_store.dart';

final aiCredentialStoreProvider = Provider<AiCredentialStore>(
  (ref) => const SecureAiCredentialStore(),
);

final chatGptAuthServiceProvider = Provider<ChatGptAuthService>((ref) {
  final service = ChatGptAuthService(
    credentials: ref.watch(aiCredentialStoreProvider),
    callbackPage: () => ChatGptCallbackPage(
      title: lang.settingsAiChatGptCallbackTitle,
      message: lang.settingsAiChatGptCallbackMessage,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});

final aiClientFactoryProvider = Provider<AiClientFactory>(
  (ref) => AiClientFactory(
    credentials: ref.watch(aiCredentialStoreProvider),
    chatGptAuth: ref.watch(chatGptAuthServiceProvider),
  ),
);

final chatGptModelCatalogProvider = Provider<ChatGptModelCatalog>(
  (ref) => ChatGptModelCatalog(
    accessToken: ref.watch(chatGptAuthServiceProvider).accessToken,
  ),
);
