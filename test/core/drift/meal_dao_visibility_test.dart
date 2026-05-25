import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('hides low treatments from regular meal lists', () async {
    final baseTime = DateTime(2026, 5, 24, 12);
    final visibleMeal = await _insertMeal(
      db,
      name: 'Obiad',
      plannedAt: baseTime,
      status: 'summarized',
    );
    final skippedMeal = await _insertMeal(
      db,
      name: 'Pominięty',
      plannedAt: baseTime.add(const Duration(minutes: 5)),
      status: 'skipped',
    );
    final confirmedMeal = await _insertMeal(
      db,
      name: 'Potwierdzony',
      plannedAt: baseTime.add(const Duration(minutes: 10)),
      status: 'confirmed',
    );
    await _insertMeal(
      db,
      name: 'Dosłodzenie',
      plannedAt: baseTime.add(const Duration(minutes: 15)),
      purpose: 'lowTreatment',
      status: 'confirmed',
    );

    final recent = await db.mealDao.watchRecentMeals(limit: 10).first;
    final events = await db.mealDao.getMealsBetween(
      baseTime.subtract(const Duration(minutes: 1)),
      baseTime.add(const Duration(hours: 1)),
    );

    expect(recent.map((meal) => meal.id), [
      confirmedMeal.id,
      skippedMeal.id,
      visibleMeal.id,
    ]);
    expect(events.map((meal) => meal.id), [
      visibleMeal.id,
      skippedMeal.id,
      confirmedMeal.id,
    ]);
  });
}

Future<MealData> _insertMeal(
  DatabaseImpl db, {
  required String name,
  required DateTime plannedAt,
  required String status,
  String purpose = 'meal',
}) {
  return db
      .into(db.meal)
      .insertReturning(
        MealCompanion.insert(
          name: name,
          plannedAt: plannedAt.millisecondsSinceEpoch,
          purpose: Value(purpose),
          status: Value(status),
        ),
      );
}
