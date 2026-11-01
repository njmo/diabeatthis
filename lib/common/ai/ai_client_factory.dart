import '../../core/llm/firebase_ai_image_client.dart';
import '../../core/llm/firebase_ai_llm_client.dart';
import '../../core/llm/local_llm_client.dart';
import '../../core/llm/openai_image_client.dart';
import '../../core/llm/openai_llm_client.dart';
import 'ai_configuration.dart';
import 'ai_credential_store.dart';
import 'ai_image_client.dart';
import 'ai_provider_kind.dart';
import 'auth/chat_gpt_auth_service.dart';
import 'unavailable_ai_image_client.dart';

const openAiApiKeyStorageKey = 'ai.openai.api-key';

class AiClientFactory {
  const AiClientFactory({required this.credentials, required this.chatGptAuth});

  final AiCredentialStore credentials;
  final ChatGptAuthService chatGptAuth;

  LocalLlmClient create(
    AiConfiguration configuration, {
    String? apiKey,
    int maxOutputTokens = 8192,
    int? thinkingBudget = 2048,
  }) {
    if (configuration.model.trim().isEmpty) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unavailable,
        message: 'An AI model must be selected.',
      );
    }
    return switch (configuration.provider) {
      AiProviderKind.firebase => FirebaseAiLlmClient(
        modelName: configuration.firebaseModel,
        gateway: FirebaseAiGenerateContentGateway(
          maxOutputTokens: maxOutputTokens,
          thinkingBudget: thinkingBudget,
        ),
      ),
      AiProviderKind.openAi => OpenAiLlmClient(
        modelName: configuration.openAiModel,
        maxOutputTokens: maxOutputTokens,
        accessToken: () => openAiAccessToken(apiKey: apiKey),
      ),
      AiProviderKind.chatGpt => OpenAiLlmClient(
        modelName: configuration.chatGptModel,
        accessToken: chatGptAuth.accessToken,
        useChatGptPlan: true,
      ),
    };
  }

  AiImageClient createImageClient(
    AiConfiguration configuration, {
    Duration timeout = const Duration(seconds: 120),
  }) => !configuration.canGenerateImages
      ? const UnavailableAiImageClient()
      : switch (configuration.effectiveImageProvider) {
          AiProviderKind.firebase => FirebaseAiImageClient(timeout: timeout),
          AiProviderKind.openAi => OpenAiImageClient(
            accessToken: openAiAccessToken,
            timeout: timeout,
          ),
          AiProviderKind.chatGpt => const UnavailableAiImageClient(),
        };

  Future<String> openAiAccessToken({String? apiKey}) async {
    final key = apiKey?.trim().isNotEmpty == true
        ? apiKey!.trim()
        : await credentials.read(openAiApiKeyStorageKey);
    if (key == null || key.trim().isEmpty) {
      throw const LlmRequestException(
        failure: LlmRequestFailure.unauthorized,
        message: 'An OpenAI API key is required.',
      );
    }
    return key;
  }
}
