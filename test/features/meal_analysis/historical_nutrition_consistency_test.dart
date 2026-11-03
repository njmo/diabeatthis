import 'dart:convert';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/historical_nutrition_scenario.dart';
import 'meal_ai_test_fixtures.dart';

Map<String, dynamic> nutritionSection(String text, String id) =>
    jsonDecode(
          text
              .split('\n')
              .singleWhere((line) => line.startsWith('$id '))
              .substring(id.length + 1),
        )
        as Map<String, dynamic>;

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late HistoricalNutritionScenario scenario;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    scenario = HistoricalNutritionScenario(db);
    await scenario.seedIngredient();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  for (final consumed in [true, false]) {
    test(
      'two ingredient revisions preserve ${consumed ? "consumed" : "planned"} macro, confidence and observation window across both analyses',
      () async {
        final id = await scenario.seedMeal(consumed: consumed);
        final before = await (db.select(db.mealSnapshot)).get();
        await scenario.revise(
          at: DateTime(2026, 9, 2),
          carbs: 25,
          fat: 12,
          confidence: .7,
        );
        await scenario.revise(
          at: DateTime(2026, 9, 3),
          carbs: 30,
          fat: 40,
          confidence: .9,
        );
        final details = await container.read(loadMealDetailsUseCaseProvider)(
          id,
        );
        final facts = const MealAiFactsMapper().map(details);
        final daily = await DayAnalysisMealRepository(db).loadMeal(id);
        final expectedNet = consumed ? 22.5 : 30.0;
        expect(facts.macros!.netCarbsGrams, expectedNet);
        expect(daily.macros!.netCarbsGrams, expectedNet);
        expect(facts.macros!.fatGrams, consumed ? 6 : 8);
        expect(facts.evidence.nutritionConfidence!.carbsNutrition, .4);
        expect(daily.evidence.nutritionConfidence!.carbsNutrition, .4);
        expect(facts.evidence.nutritionConfidence!.carbsQuantity, .8);
        expect(
          details.ingredients.single.currentNutrition.nutritionConfidence,
          .9,
        );
        expect(details.ingredients.single.plannedNutrition.carbsPer100g, 20);
        expect(details.ingredients.single.consumedNutrition.carbsPer100g, 20);
        expect(
          details.observationWindow,
          consumed ? const Duration(minutes: 90) : const Duration(hours: 3),
        );
        expect(daily.window, details.observationWindow);
        final observed = await aiObservation(id: id, time: scenario.eatenAt);
        final document = serializeMealDml(
          MealAiContext(
            current: MealAiObservation(
              meal: facts,
              before: observed.before,
              outcome: observed.outcome,
            ),
            builtAt: DateTime(2026, 9, 4),
            comparisons: [],
            failures: {},
          ),
        );
        expect(
          nutritionSection(document.text, 'meal')['net_carbs_g'],
          expectedNet,
        );
        final revision =
            (nutritionSection(
                          document.text,
                          'meal_nutrition_revisions',
                        )['items']
                        as List)
                    .single
                as Map;
        expect(
          revision['net_carbs_difference_for_recorded_quantity_g'],
          consumed ? 15 : 20,
        );
        expect(revision['recorded_nutrition_confidence'], .4);
        expect(revision['current_nutrition_confidence'], .9);
        expect(revision['change_basis'], 'unknown');
        expect(
          (await db.select(db.mealSnapshot).get()).map((row) => row.toJson()),
          before.map((row) => row.toJson()),
        );
      },
    );
  }

  test(
    'explicit zero consumption stays zero and never falls back to planned nutrition or similarity search',
    () async {
      final id = await scenario.seedMeal(zeroConsumed: true);
      final details = await container.read(loadMealDetailsUseCaseProvider)(id);
      final facts = const MealAiFactsMapper().map(details);
      expect(facts.macroSource, 'consumed');
      expect(facts.macros!.netCarbsGrams, 0);
      expect(facts.macros!.totalGrams, 0);
      expect(facts.ingredients, isEmpty);
      expect(facts.nutritionRevisions, isEmpty);
      expect(facts.evidence.nutritionConfidence!.carbsNutrition, isNull);
      final result =
          await FindSimilarMealsUseCase(
            loadMeals: (_, _, _) => throw StateError(
              'Zero consumption must not fetch comparable meals',
            ),
          )(
            mealId: id,
            asOf: DateTime(2026, 9, 4),
            target: facts.macros!,
            composition: facts.composition,
          );
      expect(result.matches, isEmpty);
      expect(
        (await DayAnalysisMealRepository(
          db,
        ).loadMeal(id)).macros!.netCarbsGrams,
        0,
      );
    },
  );

  test(
    'legacy meal without snapshots has unknown macros in both LLM paths instead of current-product nutrition',
    () async {
      final id = await scenario.seedMeal(snapshots: false);
      await scenario.revise(
        at: DateTime(2026, 9, 2),
        carbs: 30,
        fat: 40,
        confidence: .9,
      );
      final details = await container.read(loadMealDetailsUseCaseProvider)(id);
      final facts = const MealAiFactsMapper().map(details);
      final daily = await DayAnalysisMealRepository(db).loadMeal(id);
      expect(facts.macros, isNull);
      expect(daily.macros, isNull);
      expect(facts.evidence.nutritionConfidence, isNull);
      expect(daily.evidence.nutritionConfidence, isNull);
      expect(facts.macroSource, 'missing');
      expect(daily.macroSource, 'missing');
      expect(details.ingredients.single.currentNutrition.carbsPer100g, 30);
    },
  );
  test(
    'an extra ingredient added after planning retains known consumption-time confidence',
    () async {
      final id = await scenario.seedMeal();
      final addedAt = scenario.eatenAt
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch;
      final consumedAt = scenario.eatenAt
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch;
      await (db.update(db.ingredient)
            ..where((row) => row.id.equals(scenario.ingredientId)))
          .write(IngredientCompanion(createdAt: Value(addedAt)));
      await (db.update(
        db.mealIngredients,
      )..where((row) => row.mealId.equals(id))).write(
        MealIngredientsCompanion(
          entryType: const Value('extra'),
          createdAt: Value(addedAt),
          updatedAt: Value(addedAt),
        ),
      );
      await (db.update(db.mealSnapshot)..where(
            (row) =>
                row.mealId.equals(id) & row.snapshotType.equals('consumed'),
          ))
          .write(
            MealSnapshotCompanion(
              createdAt: Value(consumedAt),
              updatedAt: Value(consumedAt),
            ),
          );
      await scenario.revise(
        at: DateTime(2026, 9, 2),
        carbs: 30,
        fat: 40,
        confidence: .9,
      );
      final details = await container.read(loadMealDetailsUseCaseProvider)(id);
      final facts = const MealAiFactsMapper().map(details);
      final revision = facts.nutritionRevisions.single;
      expect(facts.macros!.netCarbsGrams, 22.5);
      expect(
        revision.historicalUnavailable,
        false,
        reason: 'A missing planned state must not erase a known consumed state',
      );
      expect(revision.recordedConfidence, .4);
      expect(revision.confidenceIncreased, true);
      expect(
        revision.toJson()['net_carbs_difference_for_recorded_quantity_g'],
        15,
      );
    },
  );
}
