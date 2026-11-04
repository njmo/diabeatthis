import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_service.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/configured_ai_service.dart';
import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/ai/helpers/recording_ai_client_factory.dart';
import '../../common/ai/helpers/recording_ai_credential_store.dart';

void main() {
  const schema = <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'name': <String, Object?>{'type': 'string'},
    },
    'required': <String>['name'],
  };
  test(
    'Firebase request schema and output overrides preserve thinking settings without changing defaults',
    () {
      const original = FirebaseAiGenerateContentGateway(
        maxOutputTokens: 2048,
        thinkingBudget: 1024,
      );
      final custom = original
          .withOutputTokenLimit(8192)
          .withResponseJsonSchema(schema);
      expect(custom.generationConfig.toJson()['responseJsonSchema'], schema);
      expect(custom.generationConfig.toJson()['maxOutputTokens'], 8192);
      expect(custom.generationConfig.toJson()['thinkingConfig'], {
        'thinkingBudget': 1024,
      });
      expect(
        custom
            .withOutputTokenLimit(4096)
            .generationConfig
            .toJson()['responseJsonSchema'],
        schema,
      );
      expect(
        original.generationConfig.toJson().containsKey('responseJsonSchema'),
        false,
      );
      expect(original.maxOutputTokens, 2048);
    },
  );
  test(
    'configured AI preserves opt-in request schema and leaves later ordinary photo requests unconstrained',
    () async {
      final credentials = RecordingAiCredentialStore();
      final auth = ChatGptAuthService(credentials: credentials);
      addTearDown(auth.dispose);
      final factory = RecordingAiClientFactory(
        credentials: credentials,
        chatGptAuth: auth,
      );
      final service = ConfiguredAiService(
        configuration: Future.value(const AiConfiguration()),
        factory: factory,
      );
      await service.analyze(
        const LocalLlmRequest(
          prompt: 'Synthetic structured meal',
          maxOutputTokens: 8192,
          responseJsonSchema: schema,
        ),
        purpose: AiAnalysisPurpose.photo,
      );
      expect(factory.client.requests.single.responseJsonSchema, same(schema));
      expect(factory.outputLimits.single, 8192);
      await service.analyze(
        const LocalLlmRequest(prompt: 'Ordinary scanner'),
        purpose: AiAnalysisPurpose.photo,
      );
      expect(factory.client.requests.last.responseJsonSchema, isNull);
      expect(factory.outputLimits.last, 2048);
    },
  );
}
