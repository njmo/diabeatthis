import 'dart:convert';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_event_treatment.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';

import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_ai_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart';

void main() {
  test(
    'DML keeps date transitions, source quality and scheduled semantics without storage identities',
    () async {
      final document = await aiDocument();
      Map<String, dynamic> section(String id) =>
          jsonDecode(
                document.text
                    .split('\n')
                    .firstWhere((l) => l.startsWith('$id '))
                    .substring(id.length + 1),
              )
              as Map<String, dynamic>;
      final blocks = section('meal_cgm')['blocks'] as List;
      expect(blocks.map((b) => b['date']), ['2026-09-10', '2026-09-11']);
      expect(blocks[0]['rows'][0], ['23:45', 120]);
      expect(blocks[1]['rows'][0], ['00:05', 165]);
      expect(section('meal')['macro_source'], 'consumed');
      expect(section('meal_outcome')['basal_u'], isNull);
      expect(section('meal_outcome')['window_complete'], isTrue);
      expect(document.text, isNot(contains('private-id')));
      expect(document.text, isNot(contains('meal_id')));
      expect(
        document.evidenceIds,
        containsAll(['meal_before', 'meal_outcome', 'meal_stress_events']),
      );
    },
  );
  test(
    'calculator submission is counted once; stress and earlier eCarbs stay visible',
    () async {
      final t = aiMealTime;
      final records = TreatmentFactory().parseTreatments([
        {
          '_id': 'private-carbs',
          'eventType': 'Carb Correction',
          'created_at': t
              .subtract(const Duration(seconds: 1))
              .toIso8601String(),
          'carbs': 30,
        },
        {
          '_id': 'private-wizard',
          'eventType': 'Bolus Wizard',
          'created_at': t.toIso8601String(),
          'glucose': 125,
          'bolusCalculatorResult': {'carbs': 30, 'totalInsulin': 1.5},
        },
        {
          '_id': 'private-bolus',
          'eventType': 'Meal Bolus',
          'created_at': t.add(const Duration(seconds: 1)).toIso8601String(),
          'insulin': 1.5,
        },
      ]);
      final stress = StressEventTreatment(
        StressEvent(
          occurredAt: t.subtract(const Duration(minutes: 10)),
          source: 'manual',
          stressLevel: StressLevel.high,
          endedAt: t.add(const Duration(minutes: 20)),
        ),
      );
      final observed = await aiObservation(
        treatments: [
          ...records,
          stress,
          ExtendedCarb(
            externalId: 'private-ecarbs',
            createdAt: t.subtract(const Duration(hours: 1)),
            carbs: 20,
            duration: 7200000,
          ),
        ],
      );
      final document = serializeMealDml(
        MealAiContext(
          current: observed,
          builtAt: t.add(const Duration(days: 1)),
          comparisons: [],
          failures: {},
        ),
      );
      Map<String, dynamic> section(String id) =>
          jsonDecode(
                document.text
                    .split('\n')
                    .firstWhere((l) => l.startsWith('$id '))
                    .substring(id.length + 1),
              )
              as Map<String, dynamic>;
      final rows = (section('meal_insulin')['blocks'] as List)
          .expand((b) => b['rows'] as List)
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single, ['23:50', 'manual', 1.5]);
      final carbs = (section('meal_carbohydrate_records')['blocks'] as List)
          .expand((b) => b['rows'] as List)
          .toList();
      expect(carbs.map((r) => r[2]), [30, 30]);
      expect(carbs.map((r) => r[1]), ['recorded_carbs', 'calculator_carbs']);
      expect(
        (section('meal_stress_events')['blocks'] as List).expand(
          (b) => b['rows'] as List,
        ),
        hasLength(1),
      );
      final overlaps = section('meal_outcome')['ecarbs_overlap'] as List;
      expect(overlaps.single['scheduled_g'], 10);
      expect(overlaps.single['started_before_meal'], true);
      expect(document.text, isNot(contains('private-')));
    },
  );
  test(
    'partial outcome remains partial and does not suggest that coverage is complete',
    () async {
      final observation = await aiObservation(elapsed: 30);
      final document = serializeMealDml(
        MealAiContext(
          current: observation,
          builtAt: aiMealTime,
          comparisons: [],
          failures: {'similar_search'},
        ),
      );
      expect(document.text, contains('"window_complete":false'));
      expect(document.text, contains('"basal_coverage":0.0'));
      expect(document.text, contains('similar_search'));
    },
  );
  test(
    'only three earlier completed comparisons are loaded, at most two concurrently',
    () async {
      final current = await aiObservation();
      var running = 0;
      var peak = 0;
      final loaded = <int>[];
      final context = await BuildMealAiContextUseCase(
        now: () => aiMealTime,
        loadObservation: (id, cutoff) async {
          if (id == 1) return current;
          loaded.add(id);
          running++;
          if (running > peak) peak = running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          expect(cutoff, aiMealTime);
          return aiObservation(
            id: id,
            time: aiMealTime.subtract(Duration(days: id)),
          );
        },
        loadSimilar: (_) async => SimilarMealContext(
          asOf: aiMealTime,
          searchStart: aiMealTime.subtract(const Duration(days: 90)),
          target: current.meal.macros!,
          matches: [
            for (var i = 2; i < 7; i++)
              SimilarMealMatch(
                meal: RecordedMealContext(
                  mealId: i,
                  name: 'Earlier',
                  eatenAt: aiMealTime.subtract(Duration(days: i)),
                  snapshot: null,
                ),
                distance: 0,
              ),
          ],
        ),
      )(1);
      expect(loaded, [2, 3, 4]);
      expect(peak, 2);
      expect(context.comparisons.length, 3);
    },
  );
  test('optional search failure leaves current evidence available', () async {
    final current = await aiObservation();
    final context = await BuildMealAiContextUseCase(
      now: () => aiMealTime,
      loadObservation: (_, _) async => current,
      loadSimilar: (_) => throw StateError('offline'),
    )(1);
    expect(context.current, same(current));
    expect(context.failures, {'similar_search'});
  });
  test(
    'rejects unfinished comparison outcomes without losing current meal',
    () async {
      final current = await aiObservation();
      final context = await BuildMealAiContextUseCase(
        now: () => aiMealTime,
        loadObservation: (id, _) async => id == 1
            ? current
            : await aiObservation(
                id: id,
                time: aiMealTime.subtract(const Duration(days: 1)),
                elapsed: 20,
              ),
        loadSimilar: (_) async => SimilarMealContext(
          asOf: aiMealTime,
          searchStart: aiMealTime.subtract(const Duration(days: 90)),
          target: current.meal.macros!,
          matches: [
            SimilarMealMatch(
              meal: RecordedMealContext(
                mealId: 2,
                name: 'Earlier',
                eatenAt: aiMealTime.subtract(const Duration(days: 1)),
                snapshot: null,
              ),
              distance: 0,
            ),
          ],
        ),
      )(1);
      expect(context.comparisons, isEmpty);
      expect(context.failures, {'comparison_1'});
    },
  );
}
