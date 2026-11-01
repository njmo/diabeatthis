import 'dart:typed_data';

import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_image_client.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/configured_ai_service.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/recording_ai_client_factory.dart';
import 'helpers/recording_ai_credential_store.dart';

class ImageSelectionFactory extends RecordingAiClientFactory {
  ImageSelectionFactory({
    required super.credentials,
    required super.chatGptAuth,
  });
  final routes = <AiProviderKind>[];
  final image = ImageSelectionClient();
  @override
  AiImageClient createImageClient(
    AiConfiguration configuration, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    routes.add(configuration.effectiveImageProvider);
    return image;
  }
}

class ImageSelectionClient implements AiImageClient {
  Object? failure;
  @override
  Future<Uint8List> generate(String prompt) async {
    if (failure != null) throw failure!;
    return Uint8List.fromList([1]);
  }
}

void main() {
  test(
    'legacy settings inherit and explicit image selection survives roundtrip',
    () {
      const original = AiConfiguration(provider: AiProviderKind.chatGpt);
      expect(
        AiConfiguration.fromJson(original.toJson()).effectiveImageProvider,
        AiProviderKind.chatGpt,
      );
      final separate = original.copyWith(imageProvider: AiProviderKind.openAi);
      final restored = AiConfiguration.fromJson(separate.toJson());
      expect(restored.provider, AiProviderKind.chatGpt);
      expect(restored.effectiveImageProvider, AiProviderKind.openAi);
      expect(restored.requiresApiKey, isTrue);
      expect(
        restored
            .copyWith(provider: AiProviderKind.firebase)
            .effectiveImageProvider,
        AiProviderKind.openAi,
      );
      expect(
        restored.copyWith(inheritImageProvider: true).effectiveImageProvider,
        AiProviderKind.chatGpt,
      );
      expect(
        () => AiConfiguration.fromJson({
          ...original.toJson(),
          'imageProvider': 'unknown',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'common service routes analyses and images independently without fallback',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = ImageSelectionFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final service = ConfiguredAiService(
        configuration: Future.value(
          const AiConfiguration(
            provider: AiProviderKind.chatGpt,
            imageProvider: AiProviderKind.openAi,
            chatGptModel: 'selected-model',
          ),
        ),
        factory: factory,
      );
      await service.analyze(
        const LocalLlmRequest(prompt: 'Synthetic analysis'),
      );
      await service.generateImage('Synthetic image');
      expect(factory.configurations.single.provider, AiProviderKind.chatGpt);
      expect(factory.routes, [AiProviderKind.openAi]);
      factory.image.failure = const LlmRequestException(
        failure: LlmRequestFailure.quotaExceeded,
        message: 'Synthetic failure',
      );
      await expectLater(
        service.generateImage('Synthetic image'),
        throwsA(same(factory.image.failure)),
      );
      expect(factory.routes, [AiProviderKind.openAi, AiProviderKind.openAi]);
    },
  );
}
