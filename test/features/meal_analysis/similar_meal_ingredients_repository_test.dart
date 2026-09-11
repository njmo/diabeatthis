import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'batch composition uses consumed amounts, merges duplicates and rejects later edits',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final cutoff = DateTime(2026, 9, 10, 12);
      final at = cutoff
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO ingredient(id,name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES(1,'Bread',40,1,1,5,1)",
      );
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status,updated_at) VALUES(1,'Meal',?,'eaten',?)",
        [at, at],
      );
      await db.customStatement(
        "INSERT INTO meal_snapshot(meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,created_at,updated_at) VALUES(1,'consumed',30,12,0,12,0,0,48,?,?)",
        [at, at],
      );
      for (final amount in [10, 20]) {
        await db.customStatement(
          'INSERT INTO meal_ingredients(meal_id,ingredient_id,amount,consumed_amount,quantity_confidence,created_at,updated_at) VALUES(1,1,5,?,1,?,?)',
          [amount, at, at],
        );
      }
      final repo = MealContextLocalHistoryRepository(db);
      final start = cutoff.subtract(const Duration(days: 2));
      expect(
        (await repo.loadSimilarMeals(
          start,
          cutoff,
          null,
        )).single.composition!.grams,
        {1: 30},
      );
      await db.customStatement(
        'UPDATE meal_ingredients SET updated_at = ? WHERE id = 1',
        [cutoff.add(const Duration(minutes: 1)).millisecondsSinceEpoch],
      );
      expect(
        (await repo.loadSimilarMeals(start, cutoff, null)).single.composition,
        isNull,
      );
    },
  );
}
