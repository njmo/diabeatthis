import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_model_response.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_response_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

class MalformedDiagnosticClient extends TestPhotoClient {
  @override
  Future<String> describe(MealPhotoInput input) async => '{"broken":';
}

class TruncatedDiagnosticClient extends TestPhotoClient {
  @override
  Future<String> describe(MealPhotoInput input) async =>
      throw const LlmOutputLimitException('{"partial":');
}

void main() {
  test(
    'the single successful response is retained for explicit diagnostics',
    () async {
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Cooked potatoes',
        ),
        languageCode: 'en',
      );
      expect(controller.responses.map((r) => r.stage), [
        MealPhotoResponseStage.description,
      ]);
      expect(
        controller.responses.every((r) => r.text.isNotEmpty && !r.truncated),
        isTrue,
      );
      controller.cancel();
      expect(controller.responses, isEmpty);
    },
  );
  for (final client in [
    MalformedDiagnosticClient(),
    TruncatedDiagnosticClient(),
  ]) {
    test(
      'invalid response remains available without becoming a proposal: ${client.runtimeType}',
      () async {
        final saver = TestPhotoSaver();
        final controller = MealPhotoController(
          propose: ProposeMealFromPhotoUseCase(
            client: client,
            candidates: TestPhotoCandidates(),
          ),
          saver: saver,
        );
        addTearDown(controller.dispose);
        await controller.generate(
          const MealPhotoInput(
            mealPhotoPath: 'plate.jpg',
            description: 'Cooked potatoes',
          ),
          languageCode: 'en',
        );
        expect(
          controller.responses.single.stage,
          MealPhotoResponseStage.description,
        );
        expect(
          controller.responses.single.text,
          client is TruncatedDiagnosticClient ? '{"partial":' : '{"broken":',
        );
        expect(
          controller.responses.single.truncated,
          client is TruncatedDiagnosticClient,
        );
        expect(controller.state.proposal, isNull);
        expect(controller.state.error, isA<FormatException>());
        expect(saver.calls, 0);
      },
    );
  }
  testWidgets(
    'copy copies latest exact JSON; preview can show the earlier stage',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const first = '{"description":"potatoes"}';
      const last = '{"resolution":"usda_123"}';
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: MealPhotoResponseActions(
              responses: [
                MealPhotoModelResponse(
                  stage: MealPhotoResponseStage.description,
                  text: first,
                ),
                MealPhotoModelResponse(
                  stage: MealPhotoResponseStage.resolution,
                  text: last,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Copy AI JSON'));
      await tester.pumpAndSettle();
      expect(copied, [last]);
      await tester.tap(find.text('Show AI JSON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dish recognition'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        first,
      );
      expect(copied, [last]);
    },
  );
}
