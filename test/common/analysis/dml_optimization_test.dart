import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/meal_advisor/data/prompts/meal_advisor_prompt.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_context.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_analysis/data/prompts/meal_ai_prompt.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/day_analysis/day_dml_test.dart' show dmlFixture;
import '../../features/day_analysis/day_timeline_dml_test.dart'
    show buildTimeline, timelineFixture;
import '../../features/meal_advisor/domain/use_cases/build_meal_advisor_context_test.dart'
    show plannedTarget;
import '../../features/meal_advisor/domain/use_cases/validate_meal_advisor_suggestion_test.dart'
    show policy;
import '../../features/meal_analysis/build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;
import '../../features/meal_analysis/meal_ai_test_fixtures.dart'
    show aiObservation;
import '../../helpers/dml_sections.dart';
import 'dml_aaps_context_test.dart' show predicted;

Future<MealAiObservation> forecastObservation(int id) async {
  final observation = await aiObservation(
    id: id,
    time: cutoff.subtract(Duration(days: id)),
  );
  final base = builder();
  final before = await BuildBeforeMealContextUseCase(
    loadGlucose: (_, _) async => observation.before.glucose!,
    loadDeviceStatuses: (_, _) async => [predicted(observation.before.asOf)],
    loadTreatments: base.loadTreatments,
    loadMeals: base.loadMeals,
    loadLowTreatments: base.loadLowTreatments,
    loadActivities: base.loadActivities,
    loadPodAge: base.loadPodAge,
    now: () => cutoff,
  )(asOf: observation.before.asOf, mealId: id, macros: observation.meal.macros);
  return MealAiObservation(
    meal: observation.meal,
    before: before,
    outcome: observation.outcome,
  );
}

void main() {
  test(
    'representative advisor, meal and day documents remain inspectable',
    () async {
      final current = await forecastObservation(1);
      final comparisons = [
        for (final id in [2, 3, 4])
          MealAiComparison(
            match: SimilarMealMatch(
              meal: RecordedMealContext(
                mealId: id,
                name: 'Reference',
                eatenAt: cutoff.subtract(Duration(days: id)),
                snapshot: null,
              ),
              distance: 0,
            ),
            observation: await forecastObservation(id),
          ),
      ];
      final meal = serializeMealDml(
        MealAiContext(
          current: current,
          builtAt: cutoff,
          comparisons: comparisons,
          failures: {},
        ),
      );
      final before = await builder(statuses: [predicted(cutoff)])(
        asOf: cutoff,
        mealId: 1,
        macros: macros,
      );
      final advisor = serializeMealAdvisorContext(
        MealAdvisorContext(
          before: before,
          target: plannedTarget(),
          builtAt: cutoff,
          comparisons: comparisons,
          failures: {},
          similarMatchCount: 3,
        ),
        requestId: 'benchmark',
      );
      final base = timelineFixture();
      final day = await buildTimeline(
        dmlFixture(),
        timelineFixture(
          statuses: [
            for (final meal in base.meals!)
              predicted(meal.eatenAt.subtract(const Duration(minutes: 1))),
          ],
        ),
      );
      final documents = {
        'advisor': advisor.text,
        'meal': meal.text,
        'day': day.text,
      };
      final prompts = {
        'advisor': mealAdvisorPrompt(advisor, language: 'pl', policy: policy),
        'meal': buildMealAiPrompt(meal, 'pl'),
        'day': buildDayAnalysisPrompt(day, 'pl'),
      };
      expect(
        dmlFactsById(advisor.text, 'current_before').keys.toSet(),
        dmlFactsById(meal.text, 'meal_before').keys.toSet(),
      );
      expect(
        dmlFactsById(day.text, 'meal:2')['before'].keys.toSet(),
        dmlFactsById(meal.text, 'meal_before').keys.toSet(),
      );
      for (final pair in [
        (advisor.text, advisor.evidenceIds),
        (meal.text, meal.evidenceIds),
        (day.text, day.evidenceIds),
      ]) {
        final forecasts = <String, Map<String, dynamic>>{};
        for (final id in pair.$2.where((id) => id.startsWith('prediction_'))) {
          forecasts[id] = dmlFactsById(pair.$1, id);
        }
        final used = <String>{};
        void references(Object? value) {
          if (value is Map) {
            for (final entry in value.entries) {
              if ((entry.key == 'ref' ||
                      (entry.key is String &&
                          (entry.key as String).endsWith('_ref'))) &&
                  entry.value is String) {
                expect(pair.$2, contains(entry.value));
              }
              references(entry.value);
            }
          } else if (value is List) {
            for (final item in value) {
              references(item);
            }
          } else if (value is String &&
              RegExp(r'^prediction_\d+$').hasMatch(value)) {
            used.add(value);
            expect(forecasts, contains(value));
          }
        }

        for (final id in pair.$2.where((id) => !id.startsWith('prediction_'))) {
          references(dmlFactsById(pair.$1, id));
        }
        expect(used, forecasts.keys.toSet());
      }
      for (final name in documents.keys) {
        expect(documents[name], startsWith('DML/1'));
        // Synthetic fixture only; records input size rather than guessing token counts.
        debugPrint(
          '$name dml_bytes=${utf8.encode(documents[name]!).length} prompt_bytes=${utf8.encode(prompts[name]!).length}',
        );
      }
    },
  );
}
