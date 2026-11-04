import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'activity context uses recorded eating time even across planned boundaries',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      Future<int> meal(String name, int planned, int actual) async {
        final id = await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: name,
                plannedAt: planned,
                status: const Value('summarized'),
              ),
            );
        await db
            .into(db.mealStatusHistory)
            .insert(
              MealStatusHistoryCompanion.insert(
                mealId: id,
                status: 'eating',
                createdAt: Value(actual),
              ),
            );
        return id;
      }

      final before = await meal('Before', 900, 90);
      final after = await meal('After', 10, 110);
      expect(
        (await db.mealDao.getCompletedMealsByRecordedTime(
          DateTime.fromMillisecondsSinceEpoch(50),
          DateTime.fromMillisecondsSinceEpoch(100),
        )).map((row) => row.id),
        [before],
      );
      expect(
        (await db.mealDao.getCompletedMealsByRecordedTime(
          DateTime.fromMillisecondsSinceEpoch(100),
          DateTime.fromMillisecondsSinceEpoch(150),
        )).map((row) => row.id),
        [after],
      );
    },
  );
}
