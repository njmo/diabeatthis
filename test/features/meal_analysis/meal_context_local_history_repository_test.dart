import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'historical meal context uses eating time and excludes later macro revisions',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final cutoff = DateTime(2026, 9, 10, 12);
      final at = cutoff
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO meal (id,name,planned_at,status) VALUES (1,'Earlier meal',?,'summarized'),(2,'Only planned',?,'planned')",
        [at, at],
      );
      await db.customStatement(
        "INSERT INTO meal_status_history (meal_id,status,created_at) VALUES (1,'eating',?)",
        [at],
      );
      for (final type in ['planned', 'consumed']) {
        final updated = type == 'consumed'
            ? cutoff.add(const Duration(minutes: 1)).millisecondsSinceEpoch
            : at;
        await db.customStatement(
          '''INSERT INTO meal_snapshot (meal_id,snapshot_type,
        total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,created_at,updated_at)
        VALUES (1,?,100,20,0,20,10,12,218,?,?)''',
          [type, at, updated],
        );
      }
      final repo = MealContextLocalHistoryRepository(db);
      final meals = await repo.loadMeals(
        cutoff.subtract(const Duration(hours: 2)),
        cutoff,
        null,
      );
      expect(meals.length, 1);
      expect(meals.single.eatenAt.millisecondsSinceEpoch, at);
      expect(meals.single.snapshot!.snapshotType.name, 'planned');
      expect(
        await repo.loadMeals(
          cutoff.subtract(const Duration(hours: 2)),
          cutoff,
          1,
        ),
        isEmpty,
      );
      await db.customStatement(
        "DELETE FROM meal_snapshot WHERE snapshot_type='planned'",
      );
      expect(
        (await repo.loadMeals(
          cutoff.subtract(const Duration(hours: 2)),
          cutoff,
          null,
        )).single.snapshot,
        isNull,
      );
    },
  );
  test(
    'activity source hides future endings and plans recorded after cutoff',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final cutoff = DateTime(2026, 9, 10, 12);
      final before = cutoff
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final after = cutoff.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO activity (id,name,percentage_pre,percentage_post,duration_minutes) VALUES (1,'Training',70,80,60)",
      );
      await db.customStatement(
        'INSERT INTO activity_log (activity_id,started_at,ended_at,created_at) VALUES (1,?,?,?),(1,?,?,?)',
        [before, after, before, after, after + 3600000, after],
      );
      final result = await MealContextLocalHistoryRepository(db).loadActivities(
        cutoff.subtract(const Duration(hours: 2)),
        cutoff.add(const Duration(hours: 3)),
        cutoff,
      );
      expect(result.length, 1);
      expect(result.single.endedAt, isNull);
      expect(result.single.percentagePost, 80);
    },
  );
}
