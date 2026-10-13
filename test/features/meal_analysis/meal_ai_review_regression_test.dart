import 'dart:convert';

import 'package:diabeatthis/features/meal_analysis/data/providers/meal_ai_provider.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_dml_document.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/accept_meal_ai_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_controller.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_state.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/meal_ai_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'meal_ai_test_fixtures.dart';

class FailedMealInputController extends MealAiInputController {
  FailedMealInputController(super.mealId);
  @override
  Future<MealDmlDocument> build() async =>
      throw StateError('History unavailable');
}

class DraftMealController extends MealAiController {
  final MealAiDraft draft;
  DraftMealController(super.request, this.draft);
  @override
  MealAiState build() => MealAiState(draft: draft);
}

void main() {
  test(
    'unavailable treatment and CGM history stay null rather than becoming observed empty lists',
    () async {
      final original = await aiObservation();
      final before = await BuildBeforeMealContextUseCase(
        loadGlucose: (_, _) async => throw StateError('Unavailable'),
        loadDeviceStatuses: (_, _) async => throw StateError('Unavailable'),
        loadTreatments: (_, _) async => throw StateError('Unavailable'),
        loadMeals: (_, _, _) async => [],
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _, _) async => [],
        loadPodAge: (_) async => null,
        now: () => aiMealTime,
      )(asOf: aiMealTime, mealId: 1, macros: original.meal.macros);
      final document = serializeMealDml(
        MealAiContext(
          current: MealAiObservation(
            meal: original.meal,
            before: before,
            outcome: null,
          ),
          builtAt: aiMealTime,
          comparisons: [],
          failures: {},
        ),
      );
      Map<String, dynamic> section(String id) =>
          jsonDecode(
                document.text
                    .split('\n')
                    .firstWhere((line) => line.startsWith('$id '))
                    .substring(id.length + 1),
              )
              as Map<String, dynamic>;
      for (final id in [
        'meal_intake_insulin',
        'meal_stress_events',
        'meal_cgm',
        'meal_pump',
      ]) {
        expect(section(id)['blocks'], isNull, reason: id);
      }
      expect(
        section('meal_before')['failed_sources'],
        containsAll(['glucose', 'deviceStatus', 'treatments']),
      );
      expect(section('meal_outcome')['available'], false);
    },
  );

  for (final save in [false, true]) {
    testWidgets(
      'failed new context permits ${save ? 'accepting' : 'discarding'} an existing draft',
      (tester) async {
        final document = await aiDocument();
        final raw = aiResponse();
        final draft = MealAiDraft(
          document: document,
          result: MealAiResult.parse(
            raw,
            language: 'pl',
            evidenceIds: document.evidenceIds,
          ),
          prompt: 'Exact input',
          rawResponse: raw,
          modelId: 'test',
          generatedAt: aiMealTime,
          promptVersion: 1,
        );
        final saved = <AcceptedMealAi>[];
        const request = (mealId: 1, language: 'pl');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealAiInputProvider(
                1,
              ).overrideWith(() => FailedMealInputController(1)),
              mealAiControllerProvider(
                request,
              ).overrideWith(() => DraftMealController(request, draft)),
              acceptedMealAiProvider.overrideWith((ref, id) async => null),
              acceptMealAiUseCaseProvider.overrideWithValue(
                AcceptMealAiUseCase(
                  save: (value) async => saved.add(value),
                  now: () => aiMealTime,
                ),
              ),
              mealAiClientProvider.overrideWith(
                (ref) => throw StateError('AI must not be initialized'),
              ),
            ],
            child: localizedMaterialApp(
              home: const Scaffold(
                body: MealAiSheet(mealId: 1, name: 'Breakfast'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        final accept = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(accept.onPressed, isNotNull);
        if (save) {
          await tester.tap(find.byType(FilledButton));
        } else {
          await tester.tap(find.text('Odrzuć propozycję'));
        }
        await tester.pumpAndSettle();
        expect(saved.length, save ? 1 : 0);
        if (save) expect(saved.single.draft, same(draft));
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
