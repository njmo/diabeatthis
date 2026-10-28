import 'dart:convert';

import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_target.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/build_meal_advisor_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_composition.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../meal_analysis/build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros, reading;
import '../../../meal_analysis/meal_ai_test_fixtures.dart' show aiObservation;

MealAdvisorTarget plannedTarget() => MealAdvisorTarget(
  mealId: 1,
  name: 'Planned breakfast',
  plannedAt: cutoff.add(const Duration(minutes: 10)),
  macros: macros,
  composition: MealComposition({1: 30}),
  confidence: null,
  ingredients: [(name: 'Bread', grams: 30)],
);
SimilarMealContext similarContext() => SimilarMealContext(
  asOf: cutoff,
  searchStart: cutoff.subtract(const Duration(days: 90)),
  target: macros,
  matches: [
    for (var i = 2; i <= 6; i++)
      SimilarMealMatch(
        meal: RecordedMealContext(
          mealId: i,
          name: 'Previous',
          eatenAt: cutoff.subtract(Duration(days: i)),
          snapshot: null,
        ),
        distance: 0,
        matchesIngredients: true,
        portionRatio: 1,
      ),
  ],
);

void main() {
  test(
    'live input contains a plan, current evidence and only completed historical outcomes',
    () async {
      final before = await builder(
        glucose: (_, _) async => [reading(-10), reading(-5), reading(0)],
      )(asOf: cutoff, mealId: 1, macros: macros);
      final loaded = <int>[];
      final context = await BuildMealAdvisorContextUseCase(
        now: () => cutoff,
        loadTarget: (_) async => plannedTarget(),
        findSimilar: (target, asOf) async => similarContext(),
        loadHistorical: (id, asOf) async {
          expect(asOf, cutoff);
          loaded.add(id);
          return aiObservation(
            id: id,
            time: cutoff.subtract(Duration(days: id)),
          );
        },
      )(before);
      expect(loaded, [2, 3, 4]);
      expect(context.comparisons, hasLength(3));
      final document = serializeMealAdvisorContext(
        context,
        requestId: 'request-1',
      );
      Map<String, dynamic> section(String id) =>
          jsonDecode(
                document.text
                    .split('\n')
                    .firstWhere((l) => l.startsWith('$id '))
                    .substring(id.length + 1),
              )
              as Map<String, dynamic>;
      expect(section('context')['scope'], 'before_meal_advisor');
      expect(section('context')['current_meal_is_planned'], true);
      expect(section('planned_meal').containsKey('eaten_at'), false);
      expect(section('planned_meal').containsKey('outcome'), false);
      expect(section('current_before')['latest_cgm_mg_dl'], 120);
      expect(section('current_before')['latest_cgm_age_min'], 0);
      expect(document.evidenceIds, contains('similar_1_record_evidence'));
      expect(document.evidenceIds, contains('similar_1_outcome'));
      expect(document.evidenceIds, isNot(contains('meal_outcome')));
    },
  );
  test(
    'an unfinished or future reference is excluded without dropping current evidence',
    () async {
      final before = await builder()(asOf: cutoff, mealId: 1, macros: macros);
      final context = await BuildMealAdvisorContextUseCase(
        now: () => cutoff,
        loadTarget: (_) async => plannedTarget(),
        findSimilar: (_, _) async => similarContext(),
        loadHistorical: (id, _) async => aiObservation(
          id: id,
          time: id == 2 ? cutoff : cutoff.subtract(Duration(days: id)),
          elapsed: id == 3 ? 10 : 90,
        ),
      )(before);
      expect(context.comparisons, hasLength(1));
      expect(context.failures, containsAll(['comparison_1', 'comparison_2']));
      expect(context.before, same(before));
    },
  );
  test(
    'missing plan details remain explicit and do not trigger speculative similarity search',
    () async {
      final before = await builder()(asOf: cutoff, mealId: 1, macros: macros);
      final context = await BuildMealAdvisorContextUseCase(
        now: () => cutoff,
        loadTarget: (_) => throw StateError('Missing plan'),
        findSimilar: (_, _) => throw StateError('Do not search'),
        loadHistorical: (_, _) => throw StateError('Do not load'),
      )(before);
      expect(context.target, isNull);
      expect(context.failures, {'target_details'});
      final document = serializeMealAdvisorContext(
        context,
        requestId: 'request-2',
      );
      expect(document.text, contains('"available":false'));
    },
  );
  test('cancellation prevents new context work from starting', () async {
    final before = await builder()(asOf: cutoff, mealId: 1, macros: macros);
    final context = await BuildMealAdvisorContextUseCase(
      now: () => cutoff,
      loadTarget: (_) => throw StateError('Do not load'),
      findSimilar: (_, _) => throw StateError('Do not search'),
      loadHistorical: (_, _) => throw StateError('Do not load'),
    )(before, isCancelled: () => true);
    expect(context.failures, {'cancelled'});
  });
}
