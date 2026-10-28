import 'dart:convert';

import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/analysis/dml_aaps_context_test.dart'
    show calculatorRecords, predicted;
import '../day_analysis/day_dml_test.dart' show dmlFixture, dmlSection;
import '../day_analysis/day_timeline_dml_test.dart'
    show buildTimeline, timelineFixture;
import 'meal_ai_test_fixtures.dart' show aiMealTime, aiObservation;

void main() {
  test(
    'day DML includes available AAPS evidence without a feature switch or altering accepted totals',
    () async {
      final accepted = dmlFixture();
      final stored = accepted.snapshot.encode();
      final base = timelineFixture();
      final mealTime = base.meals![1].eatenAt;
      final before = predicted(mealTime.subtract(const Duration(minutes: 2)));
      final after = predicted(
        mealTime.add(const Duration(minutes: 5)),
        curve: [250, 260, 270],
      );
      final history = DayAnalysisHistory(
        start: base.start,
        end: base.end,
        builtAt: base.builtAt,
        glucose: base.glucose,
        statuses: [before, after],
        treatments: [...?base.treatments, ...calculatorRecords(mealTime)],
        meals: base.meals,
        lows: base.lows,
        activities: base.activities,
        failures: {},
      );
      final document = await buildTimeline(accepted, history);
      final aaps = dmlSection(document.text, 'AAPS_CONTEXT');
      expect(aaps['calculator_blocks'], isNotEmpty);
      expect(aaps['prediction_blocks'], isNotEmpty);
      expect(document.evidenceIds, contains('aaps_context'));
      final meal = document.text
          .split('\n')
          .where((l) => l.startsWith('MEAL '))
          .map((l) => jsonDecode(l.substring(5)) as Map)
          .singleWhere((m) => m['id'] == 'meal:2');
      final prediction = meal['before']['aaps']['prediction'];
      expect(
        DateTime.parse(prediction['calculated_at'] as String),
        before.date,
      );
      expect(prediction['series']['IOB'].first, [0, 120.0]);
      expect(accepted.snapshot.encode(), stored);
    },
  );
  test(
    'meal DML keeps pre-meal forecasts separate from later forecasts and calculator totals',
    () async {
      final base = await aiObservation();
      final before = predicted(aiMealTime.subtract(const Duration(minutes: 2)));
      final after = predicted(
        aiMealTime.add(const Duration(minutes: 5)),
        curve: [250, 260, 270],
      );
      final treatments = calculatorRecords(aiMealTime);
      final preceding = await BuildBeforeMealContextUseCase(
        loadGlucose: (_, _) async => [],
        loadDeviceStatuses: (_, _) async => [before, after],
        loadTreatments: (_, _) async => treatments,
        loadMeals: (_, _, _) async => [],
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _, _) async => [],
        loadPodAge: (_) async => null,
        now: () => aiMealTime,
      )(asOf: aiMealTime, mealId: 1, macros: base.meal.macros);
      final outcome = const BuildMealOutcomeContextUseCase()(
        mealTime: aiMealTime,
        window: base.meal.window,
        asOf: aiMealTime.add(base.meal.window),
        builtAt: aiMealTime.add(base.meal.window),
        treatmentHistoryStart: aiMealTime.subtract(const Duration(hours: 24)),
        glucose: base.outcome!.glucose,
        deviceStatuses: [before, after],
        treatments: treatments,
        lowTreatments: [],
        activities: [],
        subsequentMeals: [],
      );
      final document = serializeMealDml(
        MealAiContext(
          current: MealAiObservation(
            meal: base.meal,
            before: preceding,
            outcome: outcome,
          ),
          builtAt: outcome.builtAt,
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
      expect(document.evidenceIds, contains('meal_aaps'));
      expect(
        DateTime.parse(
          section('meal_before')['aaps']['prediction']['calculated_at']
              as String,
        ),
        before.date.toUtc(),
      );
      expect(section('meal_aaps')['calculator_blocks'], isNotEmpty);
      expect(section('meal_outcome')['bolus_total_u'], outcome.boluses.units);
      expect(section('meal_outcome')['bolus_total_u'], 0);
    },
  );
}
