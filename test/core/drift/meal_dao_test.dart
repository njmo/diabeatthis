import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today meal list includes active meals from previous days', () async {
    final db = drift.DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);

    final now = DateTime(2026, 3, 23, 12);
    await withClock(Clock.fixed(now), () async {
      await db
          .into(db.meal)
          .insert(
            drift.MealCompanion.insert(
              name: 'Wczorajszy aktywny',
              plannedAt: now
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
              status: const Value('waiting-for-bolus'),
            ),
          );
      await db
          .into(db.meal)
          .insert(
            drift.MealCompanion.insert(
              name: 'Dzisiejszy plan',
              plannedAt: now
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
            ),
          );
      await db
          .into(db.meal)
          .insert(
            drift.MealCompanion.insert(
              name: 'Wczorajszy plan',
              plannedAt: now
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            ),
          );

      final meals = await db.mealDao.getAllPlannedMealForToday().first;
      final names = meals.map((meal) => meal.name);

      expect(names, contains('Wczorajszy aktywny'));
      expect(names, contains('Dzisiejszy plan'));
      expect(names, isNot(contains('Wczorajszy plan')));
    });
  });
}
