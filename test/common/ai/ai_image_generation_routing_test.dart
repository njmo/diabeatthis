import 'dart:typed_data';

import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_connection_providers.dart';
import 'package:diabeatthis/common/ai/ai_image_client.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_generation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/recording_ai_credential_store.dart';

class OpenAiImageSettings extends AiSettingsController {
  @override
  Future<AiConfiguration> build() async =>
      const AiConfiguration(provider: AiProviderKind.openAi);
}

void main() {
  late ImageRoutingFactory factory;
  late ProviderContainer container;

  setUp(() {
    final credentials = RecordingAiCredentialStore();
    final auth = ChatGptAuthService(credentials: credentials);
    addTearDown(auth.dispose);
    factory = ImageRoutingFactory(credentials: credentials, chatGptAuth: auth);
    container = ProviderContainer(
      overrides: [
        aiSettingsControllerProvider.overrideWith(OpenAiImageSettings.new),
        aiClientFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'image generation never invokes Firebase when OpenAI is selected',
    () async {
      final bytes = await container
          .read(foodIconGenerationServiceProvider)
          .generate('Synthetic apple');
      expect(bytes, factory.image.bytes);
      expect(factory.providers, [AiProviderKind.openAi]);
      expect(factory.image.prompts, ['Synthetic apple']);
    },
  );

  test('image generation failure never retries with Firebase', () async {
    factory.image.failure = const LlmRequestException(
      failure: LlmRequestFailure.quotaExceeded,
      message: 'Synthetic quota failure.',
    );
    await expectLater(
      container.read(foodIconGenerationServiceProvider).run('Synthetic apple'),
      throwsA(same(factory.image.failure)),
    );
    expect(factory.providers, [AiProviderKind.openAi]);
    expect(factory.image.prompts.single, contains('Synthetic apple'));
  });
}

class ImageRoutingFactory extends AiClientFactory {
  ImageRoutingFactory({required super.credentials, required super.chatGptAuth});

  final providers = <AiProviderKind>[];
  final image = ImageRoutingClient();

  @override
  AiImageClient createImageClient(
    AiConfiguration configuration, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    providers.add(configuration.provider);
    if (configuration.provider != AiProviderKind.openAi) {
      throw StateError('Unexpected provider: ${configuration.provider}');
    }
    return image;
  }
}

class ImageRoutingClient implements AiImageClient {
  final bytes = Uint8List.fromList([137, 80, 78, 71]);
  final prompts = <String>[];
  Object? failure;

  @override
  Future<Uint8List> generate(String prompt) async {
    prompts.add(prompt);
    if (failure != null) throw failure!;
    return bytes;
  }
}
