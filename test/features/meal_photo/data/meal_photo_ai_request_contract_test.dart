import 'dart:async';

import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_service.dart';
import 'package:diabeatthis/common/ai/ai_service_clients.dart';
import 'package:diabeatthis/common/ai/auth/chat_gpt_auth_service.dart';
import 'package:diabeatthis/common/ai/configured_ai_service.dart';
import 'package:diabeatthis/core/llm/firebase_ai_llm_client.dart';
import 'package:diabeatthis/core/llm/firebase_ai_response.dart';
import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_photo/data/local_llm_meal_photo_recognition_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../common/ai/helpers/recording_ai_client_factory.dart';
import '../../../common/ai/helpers/recording_ai_credential_store.dart';

class EmptyPhotoContractImageLoader implements LlmImageLoader {
  @override
  Future<List<LlmImageData>> loadAll(List<String> paths) async => [];
}

class PendingPhotoContractGateway extends FirebaseAiGenerateContentGateway {
  PendingPhotoContractGateway() : super(maxOutputTokens: 8192);
  @override
  FirebaseAiGenerateContentGateway withResponseJsonSchema(
    Map<String, Object?> schema,
  ) => this;
  @override
  Future<String> generate({
    required String modelName,
    required String prompt,
    required List<LlmImageData> images,
  }) => Completer<String>().future;
}

void main() {
  const input = MealPhotoInput(
    mealPhotoPath: 'plate.jpg',
    menuPhotoPath: 'menu.jpg',
    description: 'Rice with chicken',
  );
  test(
    'both meal-photo passes reserve 8192 output tokens and a bounded deadline while other scanner requests retain 2048',
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
      final client = LocalLlmMealPhotoRecognitionClient(
        AiServiceTextClient(service, AiAnalysisPurpose.photo),
      );
      await client.describe(input);
      await client.resolve(input, '{"components":[]}', {});
      expect(factory.outputLimits, [8192, 8192]);
      expect(factory.thinkingBudgets, [null, null]);
      for (final request in factory.client.requests) {
        expect(request.maxOutputTokens, 8192);
        expect(request.timeout, isNotNull);
        expect(request.timeout! > Duration.zero, true);
        expect(request.timeout! <= const Duration(seconds: 90), true);
        expect(request.imagePaths, ['plate.jpg', 'menu.jpg']);
      }
      await service.analyze(
        const LocalLlmRequest(prompt: 'Other scanner'),
        purpose: AiAnalysisPurpose.photo,
      );
      expect(factory.outputLimits.last, 2048);
      expect(factory.client.requests.last.timeout, isNull);
      expect(factory.client.requests.last.maxOutputTokens, isNull);
    },
  );
  test(
    'a stalled Firebase photo request produces a typed timeout rather than waiting indefinitely',
    () async {
      final transport = FirebaseAiLlmClient(
        gateway: PendingPhotoContractGateway(),
        imageLoader: EmptyPhotoContractImageLoader(),
      );
      final client = LocalLlmMealPhotoRecognitionClient(
        transport,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        client.describe(input),
        throwsA(
          isA<LlmRequestException>().having(
            (error) => error.failure,
            'failure',
            LlmRequestFailure.timeout,
          ),
        ),
      );
    },
  );
  test(
    'Firebase output-limit metadata is preserved as an actionable typed failure without exposing partial text in its message',
    () {
      const privateText = '{"private_meal_description":"not for logs"';
      final response = GenerateContentResponse([
        Candidate(
          Content.text(privateText),
          null,
          null,
          FinishReason.maxTokens,
          null,
        ),
      ], null);
      expect(
        () => readFirebaseAiResponse(response),
        throwsA(
          isA<LlmOutputLimitException>().having(
            (error) => error.toString(),
            'safe message',
            isNot(contains('private_meal_description')),
          ),
        ),
      );
    },
  );
  test(
    'per-request Firebase output budget keeps the established thinking configuration',
    () {
      final gateway = const FirebaseAiGenerateContentGateway(
        maxOutputTokens: 2048,
        thinkingBudget: 1024,
      ).withOutputTokenLimit(8192);
      expect(gateway.generationConfig.toJson()['maxOutputTokens'], 8192);
      expect(gateway.generationConfig.toJson()['thinkingConfig'], {
        'thinkingBudget': 1024,
      });
      expect(const FirebaseAiGenerateContentGateway().maxOutputTokens, 2048);
    },
  );
}
