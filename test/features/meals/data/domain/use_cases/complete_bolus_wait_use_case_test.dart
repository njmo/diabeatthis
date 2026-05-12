import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/complete_bolus_wait_use_case.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('stores actual wait from bolused waiting history', () async {
    final waitStartedAt = DateTime(2026, 5, 12, 12);
    final now = waitStartedAt.add(const Duration(minutes: 34));
    await _seedBolusWaitMeal(db, waitStartedAt: waitStartedAt);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await withClock(Clock.fixed(now), () {
      return container
          .read(completeBolusWaitUseCaseProvider)
          .call(
            domain.Meal(
              id: 1,
              name: 'Obiad',
              status: 'bolused-waiting',
              updatedAt: waitStartedAt,
            ),
          );
    });

    final meal = await db.mealDao.getMealById(1);
    final advisor = await (db.select(
      db.mealAdvisorResult,
    )..where((tbl) => tbl.mealId.equals(1))).getSingle();

    expect(meal?.status, 'waited-eating');
    expect(advisor.initialWaitTime, 15);
    expect(advisor.finalWaitTime, 34);
  });
}

Future<void> _seedBolusWaitMeal(
  DatabaseImpl db, {
  required DateTime waitStartedAt,
}) async {
  final timestamp = waitStartedAt.millisecondsSinceEpoch;

  await db.customInsert(
    '''
    INSERT INTO meal (
      id,
      name,
      planned_at,
      status,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?)
    ''',
    variables: [
      const Variable<int>(1),
      const Variable<String>('Obiad'),
      Variable<int>(timestamp),
      const Variable<String>('bolused-waiting'),
      Variable<int>(timestamp),
      Variable<int>(timestamp),
    ],
  );

  await db.customInsert(
    '''
    INSERT INTO meal_status_history (
      meal_id,
      status,
      created_at
    ) VALUES (?, ?, ?)
    ''',
    variables: [
      const Variable<int>(1),
      const Variable<String>('bolused-waiting'),
      Variable<int>(timestamp),
    ],
  );

  await db.customInsert(
    '''
    INSERT INTO meal_advisor_result (
      meal_id,
      result,
      initial_wait_time,
      final_wait_time,
      wait_time_ignored,
      created_at,
      updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''',
    variables: [
      const Variable<int>(1),
      const Variable<String>('bolused-waiting'),
      const Variable<int>(15),
      const Variable<int>(15),
      const Variable<bool>(false),
      Variable<int>(timestamp),
      Variable<int>(timestamp),
    ],
  );
}
