import 'package:diabeatthis/features/meal_analysis/data/domain/use_cases/build_recorded_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/before_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_outcome_context.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_assignment.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_read.dart';
import '../meals/data/repositories/nutrition_revision_test_fixture.dart';
import 'meal_ai_test_fixtures.dart';

void main() {
  for (final failure in [null, 'assignments', 'outcome']) {
    test(
      'recorded context preserves historical facts with optional failure=$failure',
      () async {
        final fixture = await aiObservation();
        final details = nutritionRevisionMeal();
        final readDetails = ScriptedRead<MealDetailsData>('meal details', [
          (arguments: [1], respond: () => details),
        ]);
        final readAssignments = ScriptedRead<List<MealWizardAssignment>>(
          'wizard assignments',
          [
            (
              arguments: [1],
              respond: () {
                if (failure == 'assignments') {
                  throw StateError('Mocked assignments failure');
                }
                return <MealWizardAssignment>[];
              },
            ),
          ],
        );
        final readBefore = ScriptedRead<BeforeMealContext>(
          'preceding history',
          [
            (
              arguments: [1, details.analysisTime, 40.0],
              respond: () => fixture.before,
            ),
          ],
        );
        final readOutcome = ScriptedRead<MealOutcomeContext?>(
          'outcome history',
          [
            (
              arguments: [details, aiMealTime],
              respond: () {
                if (failure == 'outcome') {
                  throw StateError('Mocked outcome failure');
                }
                return fixture.outcome;
              },
            ),
          ],
        );
        final useCase = BuildRecordedMealContextUseCase(
          loadDetails: (id) => readDetails([id]),
          loadAssignments: (id) => readAssignments([id]),
          loadBefore: (facts) => readBefore([
            facts.mealId,
            facts.eatenAt,
            facts.macros?.netCarbsGrams,
          ]),
          loadOutcome: (meal, cutoff) => readOutcome([meal, cutoff]),
          now: () => aiMealTime,
        );
        final result = await useCase(1, aiMealTime);
        readDetails.verifyComplete();
        readAssignments.verifyComplete();
        readBefore.verifyComplete();
        readOutcome.verifyComplete();
        expect(result.meal.macros!.netCarbsGrams, 40);
        expect(result.meal.evidence.nutritionConfidence!.carbsNutrition, .4);
        expect(
          result.meal.evidence.wizardAssignments,
          failure == 'assignments' ? isNull : isEmpty,
        );
        expect(
          result.outcome,
          failure == 'outcome' ? isNull : same(fixture.outcome),
        );
        expect(result.meal.nutritionRevisions.single.currentConfidence, .9);
        expect(
          result.meal.nutritionRevisions.single.recordedPer100g['net_carbs_g'],
          20,
        );
      },
    );
  }

  for (final request in [
    (id: 99, cutoff: aiMealTime),
    (id: 1, cutoff: DateTime(2026, 8, 1)),
  ]) {
    test(
      'invalid meal or future snapshot cannot fetch contextual history: $request',
      () async {
        final details = ScriptedRead<MealDetailsData>('meal details', [
          (arguments: [request.id], respond: nutritionRevisionMeal),
        ]);
        final assignments = ScriptedRead<List<MealWizardAssignment>>(
          'assignments',
          [
            (arguments: [request.id], respond: () => <MealWizardAssignment>[]),
          ],
        );
        final before = ScriptedRead<BeforeMealContext>('preceding history', []);
        final outcome = ScriptedRead<MealOutcomeContext?>('outcome', []);
        final useCase = BuildRecordedMealContextUseCase(
          loadDetails: (id) => details([id]),
          loadAssignments: (id) => assignments([id]),
          loadBefore: (_) => before([]),
          loadOutcome: (_, _) => outcome([]),
          now: () => aiMealTime,
        );
        await expectLater(
          useCase(request.id, request.cutoff),
          throwsStateError,
        );
        details.verifyComplete();
        assignments.verifyComplete();
        before.verifyComplete();
        outcome.verifyComplete();
      },
    );
  }
}
