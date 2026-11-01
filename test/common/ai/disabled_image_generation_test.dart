import 'package:diabeatthis/common/ai/ai_capability_unavailable_exception.dart';
import 'package:diabeatthis/common/ai/ai_client_factory.dart';
import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/configured_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/recording_ai_credential_store.dart';

void main() {
  test(
    'disabled image generation persists and never accesses remote credentials',
    () async {
      const settings = AiConfiguration(
        provider: AiProviderKind.firebase,
        imageProvider: AiProviderKind.openAi,
        imageGenerationEnabled: false,
      );
      final restored = AiConfiguration.fromJson(settings.toJson());
      expect(restored.canGenerateImages, isFalse);
      expect(restored.requiresApiKey, isFalse);
      expect(
        restored.copyWith(imageGenerationEnabled: true).canGenerateImages,
        isTrue,
      );
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final service = ConfiguredAiService(
        configuration: Future.value(restored),
        factory: AiClientFactory(credentials: credentials, chatGptAuth: auth),
      );
      await expectLater(
        service.generateImage('Synthetic image'),
        throwsA(isA<AiCapabilityUnavailableException>()),
      );
      expect(credentials.reads, isEmpty);
    },
  );
}
