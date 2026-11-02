import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal_status_flow.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_key.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/interrupt_meal_use_case.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  late DatabaseImpl db;
  late FakeNotificationsController notifications;
  late InterruptMealUseCase interrupt;
  final now = DateTime(2026, 11, 1, 19, 52);

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = FakeNotificationsController();
    interrupt = InterruptMealUseCase(
      database: db,
      notifications: notifications,
    );
  });
  tearDown(() async => db.close());

  Future<int> createMeal(String name, String status) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: name,
          plannedAt: now.millisecondsSinceEpoch,
          status: Value(status),
        ),
      );

  test(
    'stops only this meal and preserves consumed data and history',
    () async {
      final id = await createMeal('Meal', 'planned');
      final ingredientId = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Rice',
              carbsPer100g: 28,
              fatPer100g: 0.3,
              fiberPer100g: 0.4,
              proteinPer100g: 2.7,
              nutritionConfidence: 0.8,
            ),
          );
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: id,
              ingredientId: ingredientId,
              amount: const Value(150),
              consumedAmount: const Value(75),
              quantityConfidence: 0.9,
            ),
          );
      await db
          .into(db.mealSnapshot)
          .insert(
            MealSnapshotCompanion.insert(
              mealId: id,
              snapshotType: 'consumed',
              totalGrams: 75,
              totalCarbsG: 21,
              totalFiberG: 0.3,
              totalNetCarbsG: 20.7,
              totalFatG: 0.225,
              totalProteinG: 2.025,
              totalCaloriesKcal: 94,
            ),
          );
      await db.mealDao.updateMealStatus(id, 'bolused-waiting', occurredAt: now);
      await db.mealDao.updateMealStatus(id, 'waited-eating', occurredAt: now);
      final previousHistory = await db.select(db.mealStatusHistory).get();
      final previousIngredients = await db.select(db.mealIngredients).get();
      final previousSnapshots = await db.select(db.mealSnapshot).get();

      expect(await interrupt(id, expectedStatus: 'waited-eating'), isTrue);
      expect((await db.mealDao.getMealById(id))!.status, 'interrupted');
      expect(mealStatusBlocksAnotherMealActivation('interrupted'), isFalse);
      expect(await db.select(db.mealIngredients).get(), previousIngredients);
      expect(await db.select(db.mealSnapshot).get(), previousSnapshots);
      final history = await db.select(db.mealStatusHistory).get();
      expect(history, containsAll(previousHistory));
      expect(
        history.where((entry) => entry.status == 'interrupted'),
        hasLength(1),
      );
      expect(notifications.cancelAllCalled, isFalse);
      const ids = HashNotificationIdFactory();
      expect(
        notifications.cancelledIds,
        contains(
          ids.create(TempTargetNotificationEvent.meal(entityId: id).key),
        ),
      );
      expect(
        notifications.cancelledIds,
        contains(
          ids.create(
            AapsBolusSuggestionNotificationEvent(carbs: 20, mealId: id).key,
          ),
        ),
      );
      expect(
        notifications.cancelledIds,
        isNot(
          contains(
            ids.create(
              const NotificationKey(
                type: NotificationEventType.finishedEating,
                entityId: 999,
              ),
            ),
          ),
        ),
      );
      expect(
        notifications.cancelledIds,
        isNot(
          contains(
            ids.create(
              const AapsBolusSuggestionNotificationEvent(carbs: 20).key,
            ),
          ),
        ),
      );
    },
  );

  test(
    'stale asynchronous status writes cannot revive an interrupted meal',
    () async {
      final id = await createMeal('Meal', 'eating');
      await interrupt(id);
      for (final status in [
        'bolused-waiting',
        'eating',
        'waiting-for-bolus',
        'eaten',
        'summarized',
      ]) {
        expect(
          await db.mealDao.tryUpdateMealStatus(id, status, occurredAt: now),
          isFalse,
        );
      }
      expect((await db.mealDao.getMealById(id))!.status, 'interrupted');
      final history = await db.select(db.mealStatusHistory).get();
      expect(history.map((entry) => entry.status), ['interrupted']);
      expect(await interrupt(id), isTrue);
      expect(await db.select(db.mealStatusHistory).get(), hasLength(1));
    },
  );

  test(
    'reports committed interruption when notification cleanup fails',
    () async {
      final id = await createMeal('Meal', 'eating');
      notifications.enqueueCancelError(StateError('Unavailable'));
      notifications.enqueueCancelError(StateError('Still unavailable'));

      expect(await interrupt(id, expectedStatus: 'eating'), isTrue);
      expect((await db.mealDao.getMealById(id))!.status, 'interrupted');
      expect(await db.select(db.mealStatusHistory).get(), hasLength(1));
    },
  );

  test('stale status writes cannot reopen a completed summary', () async {
    final id = await createMeal('Meal', 'eating');
    await db.mealDao.updateMealStatus(id, 'eaten', occurredAt: now);
    await db.mealDao.updateMealStatus(id, 'summarized');
    final history = await db.select(db.mealStatusHistory).get();
    for (final status in [
      'eating',
      'waited-eating',
      'eaten',
      'eaten-bolused',
      'waiting-for-bolus',
    ]) {
      expect(
        await db.mealDao.tryUpdateMealStatus(id, status, occurredAt: now),
        isFalse,
      );
    }
    expect((await db.mealDao.getMealById(id))!.status, 'summarized');
    expect(await db.select(db.mealStatusHistory).get(), history);
  });

  test('a confirmed add-on can still reopen a completed summary', () async {
    final id = await createMeal('Meal', 'eaten');
    await db.mealDao.updateMealStatus(id, 'summarized');
    expect(await db.mealDao.tryUpdateMealStatus(id, 'eating-extra'), isTrue);
    expect((await db.mealDao.getMealById(id))!.status, 'eating-extra');
    expect(await db.mealDao.tryUpdateMealStatus(id, 'eaten-extra'), isTrue);
  });

  test('does not interrupt a changed or completed meal', () async {
    final id = await createMeal('Meal', 'eating');
    expect(await interrupt(id, expectedStatus: 'bolused-waiting'), isFalse);
    await db.mealDao.updateMealStatus(id, 'eaten');
    expect(await interrupt(id), isFalse);
    expect((await db.mealDao.getMealById(id))!.status, 'eaten');
    expect(notifications.cancelledIds, isEmpty);
  });

  test(
    'dashboard includes midnight and older unfinished summaries, not interrupted meals',
    () async {
      await withClock(Clock.fixed(now), () async {
        final midnight = DateTime(now.year, now.month, now.day);
        await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Midnight',
                plannedAt: midnight.millisecondsSinceEpoch,
              ),
            );
        await db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Older summary',
                plannedAt: midnight
                    .subtract(const Duration(days: 1))
                    .millisecondsSinceEpoch,
                status: const Value('eaten'),
              ),
            );
        final stopped = await createMeal('Stopped', 'eating');
        await interrupt(stopped);
        final meals = await db.mealDao.getAllPlannedMealForToday().first;
        expect(
          meals.map((meal) => meal.name),
          containsAll(['Midnight', 'Older summary']),
        );
        expect(meals.map((meal) => meal.name), isNot(contains('Stopped')));
      });
    },
  );

  test(
    'corrects eating-first end without replaying a bolus-wait transition',
    () async {
      final id = await createMeal('Meal', 'planned');
      final start = now.subtract(const Duration(hours: 5));
      await db.mealDao.updateMealStatus(
        id,
        'eating-then-bolus',
        occurredAt: start,
      );
      await db.mealDao.updateMealStatus(
        id,
        'waiting-for-bolus',
        occurredAt: now,
      );
      await db.mealDao.updateMealStatus(id, 'eaten-bolused', occurredAt: now);
      final actualEnd = start.add(const Duration(minutes: 15));
      await db.mealDao.updateMealStatusHistoryTime(
        id,
        'waiting-for-bolus',
        actualEnd,
      );
      expect((await db.mealDao.getMealById(id))!.status, 'eaten-bolused');
      final history = await db.select(db.mealStatusHistory).get();
      expect(
        history
            .singleWhere((entry) => entry.status == 'waiting-for-bolus')
            .createdAt,
        actualEnd.millisecondsSinceEpoch,
      );
      expect(
        history
            .singleWhere((entry) => entry.status == 'eaten-bolused')
            .createdAt,
        now.millisecondsSinceEpoch,
      );
    },
  );
}
