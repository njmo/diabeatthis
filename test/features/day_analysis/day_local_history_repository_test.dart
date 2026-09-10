import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses eating date and consumed totals; excludes plans and low treatments',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final start = DateTime(2026, 9, 10);
      Future<int> meal(
        String name,
        DateTime time,
        String status, {
        String purpose = 'meal',
      }) => db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: name,
              plannedAt: time.millisecondsSinceEpoch,
              status: Value(status),
              purpose: Value(purpose),
            ),
          );
      final id = await meal(
        'Cross midnight',
        start.subtract(const Duration(hours: 1)),
        'summarized',
      );
      await db
          .into(db.mealStatusHistory)
          .insert(
            MealStatusHistoryCompanion.insert(
              mealId: id,
              status: 'eating',
              createdAt: Value(
                start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
              ),
            ),
          );
      await meal('Only planned', start, 'planned');
      await meal('Low', start, 'confirmed', purpose: 'lowTreatment');
      final missing = await meal('Missing', start, 'eaten');
      expect(missing, isPositive);
      Future<void> snapshot(String type, double carbs) async {
        await db.customStatement(
          '''INSERT INTO meal_snapshot
        (meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,
        total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal)
        VALUES (?,?,100,?,0,?,5,10,100)''',
          [id, type, carbs, carbs],
        );
      }

      await snapshot('planned', 30);
      await snapshot('consumed', 20);
      final summary = await DayLocalHistoryRepository(
        db,
      ).loadMeals(start, start.add(const Duration(hours: 12)));
      expect(summary.count, 2);
      expect(summary.netCarbs, 20);
      expect(summary.missingSnapshotCount, 1);
      expect(summary.plannedFallbackCount, 0);
      await db.customStatement(
        "DELETE FROM meal_snapshot WHERE snapshot_type = 'consumed'",
      );
      final fallback = await DayLocalHistoryRepository(
        db,
      ).loadMeals(start, start.add(const Duration(hours: 12)));
      expect(fallback.netCarbs, 30);
      expect(fallback.plannedFallbackCount, 1);
    },
  );
}
