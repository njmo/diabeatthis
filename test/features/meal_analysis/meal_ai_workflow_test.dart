import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_analysis/data/clients/llm_meal_ai_client.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/meal_ai_provider.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_invalid_response.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_dml_document.dart';
import 'package:diabeatthis/features/meal_analysis/domain/services/meal_ai_client.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/accept_meal_ai_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/analyze_meal_ai_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_controller.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart';

class FakeMealAiClient implements MealAiClient {
  int calls = 0;
  String? output;
  Object? error;
  @override
  String get modelId => 'fake-local';
  @override
  Future<({String prompt, String text})> analyze(
    MealDmlDocument document, {
    required String language,
  }) async {
    calls++;
    if (error != null) throw error!;
    return (
      prompt: 'exact input',
      text: output ?? aiResponse(language: language),
    );
  }
}

class TruncatedTransport implements LocalLlmClient {
  @override
  Future<LocalLlmResponse> generate(LocalLlmRequest request) async =>
      throw const LlmOutputLimitException('{"schema_version":1');
}

void main() {
  test(
    'provider-independent transport preserves truncated output for inspection',
    () async {
      final client = LlmMealAiClient(
        transport: TruncatedTransport(),
        modelId: 'local-or-remote',
      );
      await expectLater(
        client.analyze(await aiDocument(), language: 'pl'),
        throwsA(
          isA<MealAiInvalidResponse>()
              .having((e) => e.tokenLimitReached, 'limit', true)
              .having((e) => e.response, 'partial', '{"schema_version":1'),
        ),
      );
    },
  );

  test(
    'strict validation preserves malformed raw JSON and checks known evidence and language',
    () async {
      final doc = await aiDocument();
      final client = FakeMealAiClient();
      final analyze = AnalyzeMealAiUseCase(
        client: client,
        now: () => aiMealTime,
        promptVersion: 1,
      );
      for (final invalid in [
        '{',
        aiResponse(reference: 'invented'),
        aiResponse(language: 'en'),
      ]) {
        client.output = invalid;
        await expectLater(
          analyze(doc, language: 'pl'),
          throwsA(
            isA<MealAiInvalidResponse>().having(
              (e) => e.response,
              'raw',
              invalid,
            ),
          ),
        );
      }
      final calls = client.calls;
      await expectLater(analyze(doc, language: 'de'), throwsArgumentError);
      expect(client.calls, calls);
    },
  );
  test(
    'input is reused, failed regeneration retains draft, and only acceptance saves',
    () async {
      final document = await aiDocument();
      final client = FakeMealAiClient();
      final saved = <AcceptedMealAi>[];
      final container = ProviderContainer(
        overrides: [
          mealAiInputProvider(
            1,
          ).overrideWith(() => FixtureMealAiInputController(1, document)),
          mealAiClientProvider.overrideWithValue(client),
          acceptMealAiUseCaseProvider.overrideWithValue(
            AcceptMealAiUseCase(
              save: (value) async => saved.add(value),
              now: () => aiMealTime,
            ),
          ),
          acceptedMealAiProvider.overrideWith((ref, id) async => null),
        ],
      );
      addTearDown(container.dispose);
      const request = (mealId: 1, language: 'pl');
      final subscription = container.listen(
        mealAiControllerProvider(request),
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(client.calls, 0);
      final controller = container.read(
        mealAiControllerProvider(request).notifier,
      );
      await Future.wait([controller.generate(), controller.generate()]);
      expect(client.calls, 1);
      final first = container.read(mealAiControllerProvider(request)).draft!;
      expect(saved, isEmpty);
      expect(first.document, same(document));
      client.error = StateError('offline');
      await controller.generate();
      expect(
        container.read(mealAiControllerProvider(request)).draft,
        same(first),
      );
      await controller.accept();
      expect(saved.single.draft, same(first));
      expect(container.read(mealAiControllerProvider(request)).draft, isNull);
      client.error = null;
      await controller.generate();
      controller.discard();
      expect(saved.length, 1);
    },
  );
}
