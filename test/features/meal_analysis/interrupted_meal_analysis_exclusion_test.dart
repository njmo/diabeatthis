import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final hasConsumedSnapshot in [false, true]) {
    test(
      'interrupted eating stays outside analysis with consumed snapshot $hasConsumedSnapshot',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final start = DateTime(2026, 11, 1, 8);
        final ended = start.add(const Duration(hours: 2));
        final at = start.millisecondsSinceEpoch;
        await db.customStatement(
          "INSERT INTO meal (id,name,planned_at,status,created_at,updated_at) VALUES (1,'Interrupted lunch',?,'eating',?,?)",
          [at, at, at],
        );
        await db.customStatement(
          "INSERT INTO meal_status_history (meal_id,status,created_at) VALUES (1,'bolused-waiting',?),(1,'eating',?)",
          [at, start.add(const Duration(minutes: 10)).millisecondsSinceEpoch],
        );
        await db.customStatement(
          "INSERT INTO ingredient (id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES (1,'Rice',20,1,0,2,1)",
        );
        await db.customStatement(
          'INSERT INTO meal_ingredients (meal_id,ingredient_id,amount,quantity_confidence,consumed_amount,created_at,updated_at) VALUES (1,1,100,1,?,?,?)',
          [hasConsumedSnapshot ? 50.0 : null, at, at],
        );
        await db.customStatement(
          "INSERT INTO meal_wizard_link (meal_id,remote_wizard_id,remote_source,relation_type) VALUES (1,'recorded-bolus','nightscout','initial')",
        );
        for (final type in ['planned', if (hasConsumedSnapshot) 'consumed']) {
          await db.customStatement(
            '''INSERT INTO meal_snapshot (meal_id,snapshot_type,
          total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,created_at,updated_at)
          VALUES (1,?,100,20,0,20,1,2,97,?,?)''',
            [type, at, at],
          );
        }
        final context = MealContextLocalHistoryRepository(db);
        expect(await context.loadMeals(start, ended, null), hasLength(1));
        expect(
          await context.loadSimilarMeals(start, ended, null),
          hasLength(1),
        );

        final interrupted = await withClock(
          Clock.fixed(start.add(const Duration(minutes: 15))),
          () => db.mealDao.interruptMeal(1, expectedStatus: 'eating'),
        );
        expect(interrupted, isTrue);
        expect(await context.loadMeals(start, ended, null), isEmpty);
        expect(await context.loadSimilarMeals(start, ended, null), isEmpty);

        final day = DayLocalHistoryRepository(db);
        expect(
          await day.loadRecordedMeals(start, ended, includeIds: [1]),
          isEmpty,
        );
        expect(await day.loadMealCandidates(start), isEmpty);
        final totals = await day.loadMeals(start, ended);
        expect(totals.count, 0);
        expect(totals.netCarbs, 0);
        final analysis = DayAnalysisMealRepository(db);
        expect((await analysis.loadBetween(start, ended)).meals, isEmpty);
        await expectLater(analysis.loadMeal(1), throwsStateError);

        expect(
          (await db.select(db.mealSnapshot).get()).length,
          hasConsumedSnapshot ? 2 : 1,
        );
        expect(
          (await db.select(db.mealWizardLink).get()).single.remoteWizardId,
          'recorded-bolus',
        );
        final stages = await db.select(db.mealStatusHistory).get();
        expect(
          stages.map((stage) => stage.status),
          containsAll(['bolused-waiting', 'eating', 'interrupted']),
        );
        expect(
          stages
              .singleWhere((stage) => stage.status == 'bolused-waiting')
              .createdAt,
          at,
        );
        final ingredient = (await db.select(db.mealIngredients).get()).single;
        expect(ingredient.amount, 100);
        expect(ingredient.consumedAmount, hasConsumedSnapshot ? 50 : null);
      },
    );
  }
}
