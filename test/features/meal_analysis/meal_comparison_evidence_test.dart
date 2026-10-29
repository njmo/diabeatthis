import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_context.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/assess_meal_comparison_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/dml_sections.dart';
import 'meal_ai_test_fixtures.dart';

Future<MealAiObservation> comparisonObservation({
  int beforeGlucose = 120,
  String direction = 'Flat',
  int ageMinutes = 5,
  List<int> sampleMinutes = const [],
  int elapsed = 90,
}) async {
  final base = await aiObservation();
  final at = base.meal.eatenAt;
  Glucose sample(int minute, int value) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: at.add(Duration(minutes: minute)),
    sgv: value,
    direction: direction,
  );
  final before = await BuildBeforeMealContextUseCase(
    loadGlucose: (_, _) async => [sample(-ageMinutes, beforeGlucose)],
    loadDeviceStatuses: (_, _) async => [],
    loadTreatments: (_, _) async => [],
    loadMeals: (_, _, _) async => [],
    loadLowTreatments: (_, _) async => [],
    loadActivities: (_, _, _) async => [],
    loadPodAge: (_) async => null,
    now: () => at,
  )(asOf: at, macros: null);
  final outcome = const BuildMealOutcomeContextUseCase()(
    mealTime: at,
    window: const Duration(minutes: 90),
    asOf: at.add(Duration(minutes: elapsed)),
    builtAt: at.add(Duration(minutes: elapsed)),
    treatmentHistoryStart: at.subtract(const Duration(hours: 24)),
    glucose: [for (final minute in sampleMinutes) sample(minute, 150)],
    deviceStatuses: [],
    treatments: [],
    lowTreatments: [],
    activities: [],
    subsequentMeals: [],
  );
  return MealAiObservation(meal: base.meal, before: before, outcome: outcome);
}

void main() {
  const assess = AssessMealComparisonUseCase();
  test(
    'elapsed window without CGM cannot support response comparison',
    () async {
      final reference = await comparisonObservation();
      final current = await aiObservation();
      final evidence = assess(current: current.before, reference: reference);
      expect(reference.outcome!.isTimeWindowComplete, isTrue);
      expect(evidence.responseCgmAvailable, isFalse);
      expect(evidence.responseCgmContinuous, isFalse);
      final document = serializeMealDml(
        MealAiContext(
          current: reference,
          builtAt: aiMealTime.add(const Duration(days: 1)),
          comparisons: [],
          failures: {},
        ),
      );
      final facts = dmlFactsById(document.text, 'meal_outcome');
      expect(facts['window_complete'], isTrue);
      expect(facts['has_cgm_observations'], isFalse);
      expect(facts['cgm_coverage_pct'], 0);
      final baselineOnly = await comparisonObservation(sampleMinutes: [-1]);
      expect(
        baselineOnly.outcome!.glucoseSummary.window.observed,
        isNot(Duration.zero),
      );
      expect(
        assess(
          current: current.before,
          reference: baselineOnly,
        ).responseCgmAvailable,
        isFalse,
      );
    },
  );

  test('partial and complete response histories are distinct', () async {
    final current = await aiObservation();
    final partial = await comparisonObservation(sampleMinutes: [0, 30, 60]);
    expect(
      assess(current: current.before, reference: partial).responseCgmAvailable,
      isTrue,
    );
    expect(
      assess(current: current.before, reference: partial).responseCgmContinuous,
      isFalse,
    );
    final complete = await comparisonObservation(
      sampleMinutes: [for (var m = 0; m < 90; m += 5) m],
    );
    expect(
      assess(
        current: current.before,
        reference: complete,
      ).responseCgmContinuous,
      isTrue,
    );
    final unfinished = await comparisonObservation(
      elapsed: 15,
      sampleMinutes: [0, 5, 10],
    );
    expect(
      assess(
        current: current.before,
        reference: unfinished,
      ).responseCgmContinuous,
      isFalse,
    );
  });

  test(
    'fresh starting glucose and trend differences remain separate from recipe match',
    () async {
      final current = await comparisonObservation();
      final different = await comparisonObservation(
        beforeGlucose: 219,
        direction: 'SingleUp',
      );
      final evidence = assess(current: current.before, reference: different);
      expect(evidence.startingGlucoseDelta, 99);
      expect(evidence.startingTrendMatches, isFalse);
      final stale = await comparisonObservation(
        beforeGlucose: 219,
        ageMinutes: 10,
      );
      expect(
        assess(current: current.before, reference: stale).startingGlucoseDelta,
        isNull,
      );
      expect(
        assess(current: current.before, reference: stale).startingTrendMatches,
        isNull,
      );
      final unknown = await comparisonObservation(direction: 'NONE');
      expect(
        assess(
          current: current.before,
          reference: unknown,
        ).startingTrendMatches,
        isNull,
      );
      final missingOutcome = MealAiObservation(
        meal: different.meal,
        before: different.before,
        outcome: null,
      );
      expect(
        assess(
          current: current.before,
          reference: missingOutcome,
        ).responseCgmAvailable,
        isFalse,
      );
    },
  );

  test(
    'meal and advisor export identical comparison evidence without altering ingredient match',
    () async {
      final current = await comparisonObservation();
      final reference = await comparisonObservation(
        beforeGlucose: 219,
        sampleMinutes: [0],
      );
      final comparison = MealAiComparison(
        match: SimilarMealMatch(
          meal: RecordedMealContext(
            mealId: 9,
            name: 'Reference',
            eatenAt: reference.meal.eatenAt,
            snapshot: null,
          ),
          distance: 0,
          matchesIngredients: true,
          portionRatio: 1.5,
        ),
        observation: reference,
      );
      final meal = serializeMealDml(
        MealAiContext(
          current: current,
          builtAt: aiMealTime.add(const Duration(days: 1)),
          comparisons: [comparison],
          failures: {},
        ),
      );
      final advisor = serializeMealAdvisorContext(
        MealAdvisorContext(
          before: current.before,
          target: null,
          builtAt: aiMealTime,
          comparisons: [comparison],
          failures: {},
        ),
        requestId: 'test',
      );
      for (final text in [meal.text, advisor.text]) {
        final match = dmlFactsById(text, 'similar_1_match');
        expect(match['same_ingredients'], isTrue);
        expect(match['response_cgm_available'], isTrue);
        expect(match['response_cgm_continuous'], isFalse);
        expect(
          match['starting_glucose_delta_reference_minus_current_mg_dl'],
          99,
        );
        expect(match['starting_trend_matches'], isTrue);
        expect(dmlFactsById(text, 'similar_1')['recorded_timing'], isNotNull);
      }
    },
  );
}
