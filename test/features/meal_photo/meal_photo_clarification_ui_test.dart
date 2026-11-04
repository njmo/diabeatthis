import 'dart:convert';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/llm/llm_output_limit_exception.dart';
import 'package:diabeatthis/core/llm/local_llm_client.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_clarification_required.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_failure_diagnostics.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/screens/meal_photo_review_screen.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_review_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

class ClarificationUiClient extends TestPhotoClient {
  bool clarify = true;
  @override
  Future<String> describe(MealPhotoInput input) async => clarify
      ? jsonEncode({
          'schema_version': 1,
          'status': 'needs_clarification',
          'reason': 'ambiguous_menu_item',
          'questions': ['Which section contains item 4?'],
        })
      : super.describe(input);
}

void main() {
  testWidgets(
    'clarification retains input, blocks save and allows a corrected retry',
    (tester) async {
      final client = ClarificationUiClient();
      final candidates = TestPhotoCandidates();
      final saver = TestPhotoSaver();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: client,
          candidates: candidates,
        ),
        saver: saver,
      );
      final description = TextEditingController(text: 'Item 4 from the menu');
      addTearDown(controller.dispose);
      addTearDown(description.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MealPhotoReviewScreen(
            controller: controller,
            capture: TextField(controller: description),
            pickProduct: (_) async => null,
            onSaved: (_) {},
          ),
        ),
      );
      await controller.generate(
        MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          menuPhotoPath: 'menu.jpg',
          description: description.text,
        ),
        languageCode: 'en',
      );
      await tester.pumpAndSettle();
      expect(find.text('Which section contains item 4?'), findsOneWidget);
      expect(description.text, 'Item 4 from the menu');
      expect(controller.state.step, MealPhotoStep.capture);
      expect(
        controller.state.clarification!.reason,
        MealPhotoClarificationReason.ambiguousMenuItem,
      );
      expect(controller.state.proposal, isNull);
      expect(controller.state.error, isNull);
      expect(candidates.queries, isEmpty);
      expect(
        () => controller.chooseMode(MealPhotoMode.reference),
        throwsStateError,
      );
      expect(() => controller.save(confirmed: true), throwsStateError);
      expect(saver.calls, 0);
      client.clarify = false;
      description.text = 'Item 4 in the mains section';
      await controller.generate(
        MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          menuPhotoPath: 'menu.jpg',
          description: description.text,
        ),
        languageCode: 'en',
      );
      await tester.pumpAndSettle();
      expect(controller.state.step, MealPhotoStep.mode);
      expect(controller.state.clarification, isNull);
      expect(find.text('Which section contains item 4?'), findsNothing);
      expect(candidates.queries, isEmpty);
      expect(saver.calls, 0);
    },
  );

  test('diagnostics exclude private response contents and request details', () {
    expect(
      describeMealPhotoFailure(const LlmOutputLimitException('PRIVATE_OUTPUT')),
      'response.output_limit',
    );
    expect(
      describeMealPhotoFailure(
        const FormatException('Unexpected character', 'PRIVATE_JSON'),
      ),
      'response.invalid_format',
    );
    expect(
      describeMealPhotoFailure(
        const LlmRequestException(
          failure: LlmRequestFailure.unauthorized,
          message: 'PRIVATE_TOKEN',
        ),
      ),
      'request.unauthorized',
    );
  });

  test(
    'unknown format error messages never expose payloads in diagnostics',
    () {
      const secret = 'PRIVATE_MODEL_CONTENT';
      expect(
        describeMealPhotoFailure(const FormatException(secret, secret)),
        'response.invalid_format',
      );
    },
  );

  for (final entry in <(Object, String Function(AppLocalizations))>[
    (
      const LlmOutputLimitException('PRIVATE_OUTPUT'),
      (l) => l.mealPhotoResponseIncomplete,
    ),
    (const FormatException('Bad schema'), (l) => l.mealPhotoResponseInvalid),
    (
      const LlmRequestException(
        failure: LlmRequestFailure.timeout,
        message: 'timeout',
      ),
      (l) => l.mealPhotoRequestTimeout,
    ),
  ]) {
    testWidgets(
      'model failure has an actionable localized message: ${entry.$1.runtimeType}',
      (tester) async {
        final language = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MealPhotoReviewError(error: entry.$1)),
          ),
        );
        expect(find.text(entry.$2(language)), findsOneWidget);
        expect(find.textContaining('PRIVATE'), findsNothing);
        expect(find.text(language.mealPhotoFailure), findsNothing);
      },
    );
  }
}
