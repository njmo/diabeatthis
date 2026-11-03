import 'dart:convert';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_context.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advisor_target.dart';
import 'package:diabeatthis/features/meal_advisor/domain/serialization/meal_advisor_dml.dart';
import 'package:diabeatthis/features/meal_analysis/data/domain/use_cases/build_recorded_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_composition.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/similar_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_nutrition_revision_mapper.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_nutrition_revision_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../meal_analysis/meal_ai_test_fixtures.dart';
import 'nutrition_revision_test_fixture.dart';

void main() {
  test(
    'recorded meal revisions reach a citable LLM section with old confidence',
    () async {
      final details = nutritionRevisionMeal();
      final facts = const MealAiFactsMapper().map(details);
      expect(facts.macros!.netCarbsGrams, 40);
      expect(facts.evidence.nutritionConfidence!.carbsNutrition, .4);
      final observation = await aiObservation();
      final document = serializeMealDml(
        MealAiContext(
          current: MealAiObservation(
            meal: facts,
            before: observation.before,
            outcome: observation.outcome,
          ),
          builtAt: aiMealTime,
          comparisons: const [],
          failures: const {},
        ),
      );
      expect(document.evidenceIds, contains('meal_nutrition_revisions'));
      final line = document.text
          .split('\n')
          .singleWhere((line) => line.startsWith('meal_nutrition_revisions '));
      final data = jsonDecode(line.substring(line.indexOf(' ') + 1)) as Map;
      expect(data['recorded_meal_macros_unchanged'], true);
      expect(data['items'][0]['recorded_nutrition_confidence'], .4);
      expect(data['items'][0]['current_nutrition_confidence'], .9);
      expect(
        data['items'][0]['net_carbs_difference_for_recorded_quantity_g'],
        8,
      );
      expect(details.ingredients.single.plannedNetCarbsContribution, 40);
    },
  );

  test(
    'advisor receives revisions and an explicit ingredient and quantity match',
    () async {
      final observation = await aiObservation();
      final details = nutritionRevisionMeal();
      final builder = BuildRecordedMealContextUseCase(
        loadDetails: (_) async => details,
        loadAssignments: (_) async => [],
        loadBefore: (_) async => observation.before,
        loadOutcome: (_, _) async => observation.outcome,
        now: () => aiMealTime,
      );
      final historical = await builder(1, aiMealTime);
      expect(historical.meal.nutritionRevisions.single.recordedConfidence, .4);
      for (final plannedGrams in [200.0, 150.0]) {
        final document = serializeMealAdvisorContext(
          MealAdvisorContext(
            before: observation.before,
            target: MealAdvisorTarget(
              mealId: 2,
              name: 'Rice',
              plannedAt: aiMealTime,
              macros: observation.meal.macros!,
              composition: MealComposition({2: plannedGrams}),
              confidence: null,
              ingredients: [(name: 'Rice', grams: plannedGrams)],
            ),
            builtAt: aiMealTime,
            comparisons: [
              MealAiComparison(
                match: SimilarMealMatch(
                  meal: RecordedMealContext(
                    mealId: 1,
                    name: 'Rice',
                    eatenAt: details.analysisTime,
                    snapshot: null,
                  ),
                  distance: 0,
                  matchesIngredients: true,
                ),
                observation: historical,
              ),
            ],
            failures: const {},
          ),
          requestId: 'revision-test',
        );
        expect(document.evidenceIds, contains('similar_1_nutrition_revisions'));
        final line = document.text
            .split('\n')
            .singleWhere((line) => line.startsWith('similar_1_match '));
        final data = jsonDecode(line.substring(line.indexOf(' ') + 1)) as Map;
        expect(
          data['nutrition_revision_matches'][0]['same_quantity'],
          plannedGrams == 200,
        );
        expect(
          data['nutrition_revision_matches'][0]['ingredient_present_in_planned_meal'],
          true,
        );
      }
    },
  );

  test(
    'confidence-only changes are visible without inventing a macro correction',
    () {
      final revision = const MealNutritionRevisionMapper()
          .map(nutritionRevisionMeal(currentCarbs: 20))
          .single;
      expect(revision.confidenceIncreased, true);
      expect(
        revision.toJson()['net_carbs_difference_for_recorded_quantity_g'],
        0,
      );
    },
  );

  test('unavailable history cannot be described as higher confidence', () {
    final revision = const MealNutritionRevisionMapper()
        .map(nutritionRevisionMeal(unavailable: true))
        .single;
    expect(revision.confidenceIncreased, false);
    expect(revision.toJson()['recorded_per_100g'], isNull);
  });

  test('new meals and unchanged historical meals have no revision notice', () {
    const mapper = MealNutritionRevisionMapper();
    expect(mapper.map(nutritionRevisionMeal(status: 'planned')), isEmpty);
    expect(mapper.map(nutritionRevisionMeal(changed: false)), isEmpty);
  });

  testWidgets(
    'older meal shows recorded and current values without replacing the past',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealNutritionRevisionNotice(details: nutritionRevisionMeal()),
          ),
        ),
      );
      expect(
        find.text('Dane składników doprecyzowano — pewność wzrosła'),
        findsOneWidget,
      );
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('wtedy 40g, obecnie 48g'), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
