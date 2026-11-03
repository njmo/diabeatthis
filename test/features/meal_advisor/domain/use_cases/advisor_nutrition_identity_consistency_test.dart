import 'dart:convert';

import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/meal_snapshot.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_target.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/build_meal_advisor_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_composition.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_record_evidence.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/scripted_read.dart';
import '../../../meal_analysis/meal_ai_test_fixtures.dart';
import '../../../meals/data/repositories/nutrition_revision_test_fixture.dart';

Map<String, dynamic> advisorNutritionSection(String text, String key) =>
    jsonDecode(
          text
              .split('\n')
              .singleWhere((line) => line.startsWith('$key '))
              .substring(key.length + 1),
        )
        as Map<String, dynamic>;

void main() {
  for (final scenario in [
    (ingredientId: 2, grams: 200.0),
    (ingredientId: 2, grams: 100.0),
    (ingredientId: 999, grams: 200.0),
  ]) {
    test(
      'actual identity and amount govern revision relevance, regardless of equal names: $scenario',
      () async {
        final historicalDetails = nutritionRevisionMeal();
        final facts = const MealAiFactsMapper().map(historicalDetails);
        final historicalCourse = await aiObservation(time: facts.eatenAt);
        final observation = MealAiObservation(
          meal: facts,
          before: historicalCourse.before,
          outcome: historicalCourse.outcome,
        );
        final decisionTime = DateTime(2026, 9, 10, 12);
        final macros = MealMacroSummary(
          carbsGrams: scenario.grams * .24,
          fatGrams: 0,
          proteinGrams: 0,
          fiberGrams: 0,
          totalGrams: scenario.grams,
        );
        final target = MealAdvisorTarget(
          mealId: 10,
          name: 'Rice',
          plannedAt: decisionTime,
          macros: macros,
          composition: MealComposition({scenario.ingredientId: scenario.grams}),
          confidence: const MealNutritionConfidence(
            carbsNutrition: .7,
            carbsQuantity: .8,
            carbsEffective: .56,
          ),
          ingredients: [(name: 'Rice', grams: scenario.grams)],
        );
        final before = await BuildBeforeMealContextUseCase(
          loadGlucose: (_, _) async => [],
          loadDeviceStatuses: (_, _) async => [],
          loadTreatments: (_, _) async => [],
          loadMeals: (_, _, _) async => [],
          loadLowTreatments: (_, _) async => [],
          loadActivities: (_, _, _) async => [],
          loadPodAge: (_) async => null,
          now: () => decisionTime,
        )(asOf: decisionTime, mealId: 10, macros: macros);
        final candidate = RecordedMealContext(
          mealId: 1,
          name: 'Rice',
          eatenAt: facts.eatenAt,
          composition: MealComposition({2: 200}),
          snapshot: const MealSnapshot(
            mealId: 1,
            snapshotType: MealSnapshotType.planned,
            totalGrams: 200,
            totalCarbsG: 40,
            totalFiberG: 0,
            totalNetCarbsG: 40,
            totalFatG: 0,
            totalProteinG: 0,
            totalCaloriesKcal: 160,
            ingredientsCount: 1,
            avgQuantityConfidence: .8,
            minQuantityConfidence: .8,
            carbWeightedQuantityConfidence: .8,
            wbtWeightedQuantityConfidence: null,
            carbWeightedNutritionConfidence: .4,
            wbtWeightedNutritionConfidence: null,
            carbWeightedEffectiveConfidence: .32,
            wbtWeightedEffectiveConfidence: null,
          ),
        );
        final searchReads = ScriptedRead<List<RecordedMealContext>>(
          'similar meals',
          [
            (
              arguments: [DateTime(2026, 6, 12, 12), decisionTime, 10],
              respond: () => [candidate],
            ),
          ],
        );
        final historicalReads = ScriptedRead<MealAiObservation>(
          'historical context',
          [
            (arguments: [1, decisionTime], respond: () => observation),
          ],
        );
        final useCase = BuildMealAdvisorContextUseCase(
          loadTarget: (data) async {
            expect(data.mealId, 10);
            expect(data.macros!.netCarbsGrams, scenario.grams * .24);
            return target;
          },
          findSimilar: (selected, asOf) =>
              FindSimilarMealsUseCase(
                loadMeals: (start, end, excluded) =>
                    searchReads([start, end, excluded]),
              )(
                mealId: selected.mealId,
                asOf: asOf,
                target: selected.macros,
                composition: selected.composition,
              ),
          loadHistorical: (id, cutoff) => historicalReads([id, cutoff]),
          now: () => decisionTime,
        );
        final context = await useCase(before);
        expect(context.failures, isEmpty);
        expect(context.comparisons, hasLength(1));
        final document = serializeMealAdvisorContext(
          context,
          requestId: 'nutrition-identity',
        );
        final planned = advisorNutritionSection(document.text, 'planned_meal');
        final historical = advisorNutritionSection(document.text, 'similar_1');
        final revisions = advisorNutritionSection(
          document.text,
          'similar_1_nutrition_revisions',
        );
        final match = advisorNutritionSection(document.text, 'similar_1_match');
        expect(planned['net_carbs_g'], scenario.grams * .24);
        expect(planned['nutrition_confidence']['carbs_nutrition'], .7);
        expect(planned['nutrition_confidence']['carbs_quantity'], .8);
        expect(historical['net_carbs_g'], 40);
        expect(
          advisorNutritionSection(
            document.text,
            'similar_1_record_evidence',
          )['nutrition_confidence']['carbs_nutrition'],
          .4,
        );
        final relevance =
            (match['nutrition_revision_matches'] as List).single as Map;
        expect(
          relevance['ingredient_present_in_planned_meal'],
          scenario.ingredientId == 2,
        );
        expect(
          relevance['planned_quantity_g'],
          scenario.ingredientId == 2 ? scenario.grams : null,
        );
        expect(
          relevance['same_quantity'],
          scenario.ingredientId == 2 && scenario.grams == 200,
        );
        expect(match['same_ingredients'], scenario.ingredientId == 2);
        expect(revisions['items'][0]['current_nutrition_confidence'], .9);
        expect(
          advisorNutritionSection(
            document.text,
            'similar_1_record_evidence',
          )['workflow_wait_min'],
          isNull,
        );
        expect(document.evidenceIds, isNot(contains('current_outcome')));
        searchReads.verifyComplete();
        historicalReads.verifyComplete();
      },
    );
  }
}
