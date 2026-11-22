import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/complete_bolus_wait_use_case.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../foreground/utils/fake_runtime_harness.dart';
import '../../../../../foreground/utils/pending_notifications_controller.dart';

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
    expect(advisor.waitTimeIgnored, isFalse);
  });

  test(
    'the foreground command records 3 of 5 minutes before the timer ends',
    () async {
      final started = DateTime(2026, 5, 12, 12);
      await _seedBolusWaitMeal(db, waitStartedAt: started);
      await db.customUpdate(
        'UPDATE meal_advisor_result SET initial_wait_time = 5 WHERE meal_id = 1',
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            PendingNotificationsController(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      final stored = db
          .select(db.meal)
          .watchSingle()
          .firstWhere((meal) => meal.status == 'waited-eating');
      withClock(Clock.fixed(started.add(const Duration(minutes: 3))), () {
        NotificationResponseEventHandler().handle(
          const NotificationResponseEvent.eatNowResponse(
            data: EatNowResponseEvent.eating(mealId: 1),
          ),
          harness.runtimeContext,
        );
      });
      await stored.timeout(const Duration(seconds: 3));
      final result = await db.select(db.mealAdvisorResult).getSingle();
      expect(result.initialWaitTime, 5);
      expect(result.finalWaitTime, 3);
      expect(result.waitTimeIgnored, isTrue);
    },
  );

  test(
    'marks wait as ignored when actual wait is shorter than advised',
    () async {
      final waitStartedAt = DateTime(2026, 5, 12, 12);
      final now = waitStartedAt.add(const Duration(minutes: 6));
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

      final advisor = await (db.select(
        db.mealAdvisorResult,
      )..where((tbl) => tbl.mealId.equals(1))).getSingle();

      expect(advisor.initialWaitTime, 15);
      expect(advisor.finalWaitTime, 6);
      expect(advisor.waitTimeIgnored, isTrue);
    },
  );
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
