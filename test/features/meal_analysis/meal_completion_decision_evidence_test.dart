import 'dart:convert';

import 'package:diabeatthis/common/analysis/dml_timestamp.dart';
import 'package:diabeatthis/common/meal/meal_completion_decision.dart';
import 'package:diabeatthis/features/day_analysis/data/prompts/day_analysis_prompt.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/data/prompts/meal_ai_prompt.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_facts.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_record_evidence.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_record_evidence_dml.dart';
import 'package:flutter_test/flutter_test.dart';

import '../day_analysis/day_dml_test.dart' show dmlFixture, dmlSection;
import 'meal_ai_test_fixtures.dart' show aiMealTime, aiObservation;

MealCompletionDecision completionDecision(
  DateTime recordedAt, {
  MealCarbsCorrectionChoice choice =
      MealCarbsCorrectionChoice.withoutCorrection,
}) => MealCompletionDecision(
  choice: choice,
  recordedAt: recordedAt,
  eatingEndedAt: recordedAt.subtract(const Duration(minutes: 1)),
  reportedCarbs: 40,
  consumedCarbs: 25,
  proposedCorrectionCarbs: -15,
);

MealRecordEvidence completionEvidence(MealCompletionDecision? decision) =>
    MealRecordEvidence(
      eatingTimeSource: MealEatingTimeSource.recordedStage,
      nutritionConfidence: null,
      wizardAssignments: [],
      completionDecision: decision,
    );

MealAiObservation withCompletion(
  MealAiObservation observation,
  MealCompletionDecision? decision,
) {
  final meal = observation.meal;
  return MealAiObservation(
    meal: MealAiFacts(
      mealId: meal.mealId,
      name: meal.name,
      eatenAt: meal.eatenAt,
      endedAt: meal.endedAt,
      wait: meal.wait,
      window: meal.window,
      macroSource: meal.macroSource,
      evidence: completionEvidence(decision),
      macros: meal.macros,
      composition: meal.composition,
      ingredients: meal.ingredients,
      stages: meal.stages,
    ),
    before: observation.before,
    outcome: observation.outcome,
  );
}

void main() {
  test(
    'completion JSON preserves a choice and portion difference as context only',
    () async {
      final observation = await aiObservation();
      for (final choice in MealCarbsCorrectionChoice.values) {
        final decision = completionDecision(
          aiMealTime.add(const Duration(minutes: 10)),
          choice: choice,
        );
        final facts = mealRecordEvidenceDml(
          mealId: 1,
          evidence: completionEvidence(decision),
          mealTime: aiMealTime,
          workflowWait: null,
          before: observation.before,
          outcome: observation.outcome,
          includeLimitations: false,
        );
        final json = jsonDecode(jsonEncode(facts)) as Map;
        final recorded = json['completion_decision'] as Map;
        expect(recorded['choice'], choice.name);
        expect(recorded['recorded_at'], dmlTimestamp(decision.recordedAt));
        expect(
          recorded['eating_ended_at'],
          dmlTimestamp(decision.eatingEndedAt),
        );
        expect(recorded['previously_reported_carbs_g'], 40);
        expect(recorded['consumed_carbs_g'], 25);
        expect(recorded['consumed_minus_reported_carbs_g'], -15);
        expect(recorded['proposed_correction_carbs_g'], -15);
        expect(
          recorded['later_manual_aaps_correction'],
          'unknown_from_this_choice',
        );
        expect(
          recorded['causal_link_to_later_hypoglycemia'],
          'not_established',
        );
        expect(
          recorded['source'],
          'recorded_app_choice_not_verified_aaps_action',
        );
      }
    },
  );

  test(
    'recorded choice is unknown before its cutoff and included at the boundary',
    () async {
      final observation = await aiObservation();
      final cutoff = aiMealTime.add(const Duration(hours: 2));
      for (final offset in [null, -1, 0, 1]) {
        final decision = offset == null
            ? null
            : completionDecision(cutoff.add(Duration(milliseconds: offset)));
        final facts = mealRecordEvidenceDml(
          mealId: 1,
          evidence: completionEvidence(decision),
          mealTime: aiMealTime,
          workflowWait: null,
          before: observation.before,
          outcome: observation.outcome,
          asOf: cutoff,
        );
        expect(
          facts['completion_decision'] != null,
          offset != null && offset <= 0,
        );
        expect(
          facts.containsKey('completion_decision'),
          offset != null && offset <= 0,
        );
      }
    },
  );

  test(
    'meal serializer includes saved decisions after the outcome but before analysis time',
    () async {
      final observation = await aiObservation();
      final cutoff = aiMealTime.add(const Duration(hours: 3));
      for (final offset in [0, 1]) {
        final document = serializeMealDml(
          MealAiContext(
            current: withCompletion(
              observation,
              completionDecision(cutoff.add(Duration(milliseconds: offset))),
            ),
            builtAt: cutoff,
            comparisons: [],
            failures: {},
          ),
        );
        expect(
          dmlSection(
                document.text,
                'meal_record_evidence',
              )['completion_decision'] !=
              null,
          offset == 0,
        );
        final prompt = buildMealAiPrompt(document, 'en');
        expect(
          prompt.contains(
            'does not prove that no later manual AAPS correction occurred',
          ),
          offset == 0,
        );
        expect(
          prompt.contains('do not establish a cause of later hypoglycemia'),
          offset == 0,
        );
      }
    },
  );

  test(
    'comparison cannot leak a choice recorded after the target meal',
    () async {
      final current = await aiObservation();
      final earlier = await aiObservation(
        id: 2,
        time: aiMealTime.subtract(const Duration(days: 1)),
      );
      for (final offset in [0, 1]) {
        final document = serializeMealDml(
          MealAiContext(
            current: current,
            builtAt: aiMealTime.add(const Duration(days: 1)),
            comparisons: [
              MealAiComparison(
                match: SimilarMealMatch(
                  meal: RecordedMealContext(
                    mealId: 2,
                    name: 'Earlier',
                    eatenAt: earlier.meal.eatenAt,
                    snapshot: null,
                  ),
                  distance: 0,
                ),
                observation: withCompletion(
                  earlier,
                  completionDecision(
                    aiMealTime.add(Duration(milliseconds: offset)),
                  ),
                ),
              ),
            ],
            failures: {},
          ),
        );
        expect(
          dmlSection(
                document.text,
                'similar_1_record_evidence',
              )['completion_decision'] !=
              null,
          offset == 0,
        );
      }
    },
  );

  test(
    'day serializer uses the history cutoff rather than the later build time',
    () async {
      final accepted = dmlFixture();
      final cutoff = accepted.snapshot.asOf;
      final eatenAt = cutoff.subtract(const Duration(hours: 4));
      for (final offset in [0, 1]) {
        final meal = DayAnalysisMeal(
          id: 1,
          name: 'Dinner',
          eatenAt: eatenAt,
          eatingEndedAt: eatenAt.add(const Duration(minutes: 10)),
          wait: null,
          window: const Duration(minutes: 90),
          macroSource: 'consumed',
          macros: null,
          ingredients: [],
          stages: [],
          evidence: completionEvidence(
            completionDecision(cutoff.add(Duration(milliseconds: offset))),
          ),
        );
        final history = DayAnalysisHistory(
          start: cutoff.subtract(const Duration(days: 1)),
          end: cutoff,
          builtAt: cutoff.add(const Duration(days: 1)),
          glucose: [],
          statuses: [],
          treatments: [],
          meals: [meal],
          lows: [],
          activities: [],
          failures: {},
        );
        final document = serializeDayAnalysisContext(
          await const BuildDayAnalysisContextUseCase()(accepted, history),
        );
        final facts =
            dmlSection(document.text, 'MEAL')['record_evidence'] as Map;
        expect(facts['completion_decision'] != null, offset == 0);
        expect(
          buildDayAnalysisPrompt(
            document,
            'en',
          ).contains('correctionRequested does not prove it was applied'),
          offset == 0,
        );
      }
    },
  );
}
