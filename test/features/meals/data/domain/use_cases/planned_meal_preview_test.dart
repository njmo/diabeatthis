import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_meal_transaction_test.dart' show transactionMealDraft;

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertSnapshot(int mealId, String type, double carbs) {
    return db.customStatement(
      '''
      INSERT INTO meal_snapshot (
        meal_id, snapshot_type, total_grams, total_carbs_g, total_fiber_g,
        total_net_carbs_g, total_fat_g, total_protein_g, total_calories_kcal
      ) VALUES (?, ?, 200, ?, 2, ?, 12, 8, 777)
    ''',
      [mealId, type, carbs, carbs - 2],
    );
  }

  for (final usePortions in [true, false]) {
    test(
      'previews planned nutrition without persisting a snapshot, portions: $usePortions',
      () async {
        final meal = await container
            .read(addMealUseCaseProvider)
            .call(transactionMealDraft(usePortions: usePortions));
        final details = await container
            .read(loadMealDetailsUseCaseProvider)
            .call(meal.id);
        final totals = details.plannedNutritionTotals!;
        final grams = usePortions ? 150.0 : 3.0;

        expect(totals.totalGrams, grams);
        expect(totals.totalCarbsG, closeTo(grams * .2, .000001));
        expect(totals.totalNetCarbsG, closeTo(grams * .2, .000001));
        expect(totals.totalFatG, closeTo(grams * .05, .000001));
        expect(totals.totalProteinG, closeTo(grams * .04, .000001));
        expect(totals.totalCaloriesKcal, closeTo(grams * 1.41, .000001));
        expect(details.preferredNutritionTotals, same(totals));
        expect(details.copyWith().plannedPreviewNutrition, same(totals));
        expect(details.plannedSnapshot, isNull);
        expect(details.consumedSnapshot, isNull);
        expect(details.preferredSummarySnapshot, isNull);
        expect(details.hasConsumedData, isFalse);
        expect(await db.select(db.mealSnapshot).get(), isEmpty);
      },
    );
  }

  test(
    'uses current nutrition and carbohydrate label mode before a meal starts',
    () async {
      final meal = await container
          .read(addMealUseCaseProvider)
          .call(transactionMealDraft());
      await db.customStatement('''
      UPDATE ingredient SET carbs_per_100g = 30, fiber_per_100g = 4,
        carbs_label_mode = 'non_eu'
    ''');

      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(meal.id);

      expect(details.plannedNutritionTotals!.totalCarbsG, 45);
      expect(details.plannedNutritionTotals!.totalFiberG, 6);
      expect(details.plannedNutritionTotals!.totalNetCarbsG, 39);
      expect(await db.select(db.mealSnapshot).get(), isEmpty);
    },
  );

  test(
    'reference ingredients preserve the established 100 gram amount conversion',
    () async {
      final draft = transactionMealDraft();
      final meal = await container
          .read(addMealUseCaseProvider)
          .call(
            draft.copyWith(
              mealIngredients: draft.mealIngredients
                  .map(
                    (item) => item.copyWith(
                      ingredient: item.ingredient.copyWith(isReference: true),
                    ),
                  )
                  .toList(),
            ),
          );

      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(meal.id);

      expect(details.plannedNutritionTotals!.totalGrams, 300);
      expect(details.plannedNutritionTotals!.totalCarbsG, 60);
    },
  );

  test(
    'stored planned values and calories take precedence over live ingredients',
    () async {
      final meal = await container
          .read(addMealUseCaseProvider)
          .call(transactionMealDraft());
      await insertSnapshot(meal.id, 'planned', 11);

      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(meal.id);

      expect(details.plannedPreviewNutrition, isNull);
      expect(details.plannedNutritionTotals!.totalCarbsG, 11);
      expect(details.plannedNutritionTotals!.totalNetCarbsG, 9);
      expect(details.plannedNutritionTotals!.totalCaloriesKcal, 777);
      expect(details.preferredNutritionTotals!.totalCarbsG, 11);
      expect(details.consumedSnapshot, isNull);
      expect(await db.select(db.mealSnapshot).get(), hasLength(1));
    },
  );

  test(
    'consumed snapshot remains the preferred summary without replacing the plan',
    () async {
      final meal = await container
          .read(addMealUseCaseProvider)
          .call(transactionMealDraft());
      await insertSnapshot(meal.id, 'planned', 11);
      await insertSnapshot(meal.id, 'consumed', 22);

      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(meal.id);

      expect(details.plannedPreviewNutrition, isNull);
      expect(details.plannedNutritionTotals!.totalCarbsG, 11);
      expect(details.preferredNutritionTotals!.totalCarbsG, 22);
      expect(details.hasConsumedData, isTrue);
      expect(await db.select(db.mealSnapshot).get(), hasLength(2));
    },
  );

  for (final status in [
    'waiting-for-bolus',
    'bolused-waiting',
    'eating',
    'eaten',
    'summarized',
    'skipped',
  ]) {
    test(
      'does not reconstruct missing historical values for $status',
      () async {
        final meal = await container
            .read(addMealUseCaseProvider)
            .call(transactionMealDraft());
        await db.customStatement('UPDATE meal SET status = ? WHERE id = ?', [
          status,
          meal.id,
        ]);

        final details = await container
            .read(loadMealDetailsUseCaseProvider)
            .call(meal.id);

        expect(details.plannedPreviewNutrition, isNull);
        expect(details.plannedNutritionTotals, isNull);
        expect(details.preferredNutritionTotals, isNull);
        expect(details.consumedSnapshot, isNull);
      },
    );
  }

  test(
    'does not reconstruct a previous meal after its status is reset to planned',
    () async {
      final meal = await container
          .read(addMealUseCaseProvider)
          .call(transactionMealDraft());
      await db.customStatement(
        '''
      INSERT INTO meal_status_history (meal_id, status, created_at)
      VALUES (?, 'eaten', 1)
    ''',
        [meal.id],
      );

      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(meal.id);

      expect(details.plannedPreviewNutrition, isNull);
      expect(details.plannedNutritionTotals, isNull);
      expect(details.preferredNutritionTotals, isNull);
    },
  );

  test('leaves values unknown when there are no meal ingredients', () async {
    final meal = await container
        .read(addMealUseCaseProvider)
        .call(transactionMealDraft());
    await db.customStatement('DELETE FROM meal_ingredients WHERE meal_id = ?', [
      meal.id,
    ]);

    final details = await container
        .read(loadMealDetailsUseCaseProvider)
        .call(meal.id);

    expect(details.plannedPreviewNutrition, isNull);
    expect(details.plannedNutritionTotals, isNull);
    expect(details.preferredNutritionTotals, isNull);
  });
}
