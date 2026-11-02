import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/complete_bolus_wait_use_case.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 1, 12);
  late DatabaseImpl db;
  late ProviderContainer container;
  late int mealId;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    mealId = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Lunch',
            plannedAt: start.millisecondsSinceEpoch,
          ),
        );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'generic history maintenance retains completed-status rewrites and trigger history',
    () async {
      await db.mealDao.updateMealStatus(
        mealId,
        'summarized',
        occurredAt: start,
      );
      await db.mealDao.updateMealStatus(mealId, 'eaten');
      expect((await db.mealDao.getMealById(mealId))!.status, 'eaten');
      expect(
        (await db.select(db.mealStatusHistory).get())
            .map((row) => row.status)
            .toSet(),
        {'summarized', 'eaten'},
      );
    },
  );

  test(
    'workflow DAO and both background providers cannot revive a completed meal',
    () async {
      await db.mealDao.updateMealStatus(
        mealId,
        'summarized',
        occurredAt: start,
      );
      final before = await db.select(db.mealStatusHistory).get();
      expect(await db.mealDao.tryUpdateMealStatus(mealId, 'eaten'), isFalse);
      await container.read(
        updateMealProvider(
          domain.Meal(id: mealId, name: 'Lunch', status: 'eating'),
          'eaten',
        ).future,
      );
      await container.read(
        updateMealByIdProvider(mealId, 'waiting-for-bolus').future,
      );
      expect((await db.mealDao.getMealById(mealId))!.status, 'summarized');
      expect(await db.select(db.mealStatusHistory).get(), before);
    },
  );

  test(
    'interruption remains terminal for generic and workflow status APIs',
    () async {
      await db.mealDao.interruptMeal(mealId);
      final before = await db.select(db.mealStatusHistory).get();
      await db.mealDao.updateMealStatus(mealId, 'eaten');
      expect(
        await db.mealDao.tryUpdateMealStatus(mealId, 'waiting-for-bolus'),
        isFalse,
      );
      expect((await db.mealDao.getMealById(mealId))!.status, 'interrupted');
      expect(await db.select(db.mealStatusHistory).get(), before);
    },
  );

  for (final terminal in ['summarized', 'interrupted']) {
    test(
      'delayed wait completion cannot change $terminal status or saved wait advice',
      () async {
        await db.mealDao.updateMealStatus(
          mealId,
          'bolused-waiting',
          occurredAt: start,
        );
        await db.customStatement(
          '''INSERT INTO meal_advisor_result
        (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored)
        VALUES (?, 'bolused-waiting', 15, 15, 0)''',
          [mealId],
        );
        await db.mealDao.updateMealStatus(
          mealId,
          terminal,
          occurredAt: start.add(const Duration(minutes: 20)),
        );
        final beforeHistory = await db.select(db.mealStatusHistory).get();
        final beforeAdvice = await db.select(db.mealAdvisorResult).getSingle();
        await withClock(
          Clock.fixed(start.add(const Duration(minutes: 30))),
          () => container
              .read(completeBolusWaitUseCaseProvider)
              .call(
                domain.Meal(
                  id: mealId,
                  name: 'Lunch',
                  status: 'bolused-waiting',
                  updatedAt: start,
                ),
              ),
        );
        expect((await db.mealDao.getMealById(mealId))!.status, terminal);
        expect(await db.select(db.mealStatusHistory).get(), beforeHistory);
        expect(await db.select(db.mealAdvisorResult).getSingle(), beforeAdvice);
      },
    );
  }
}
