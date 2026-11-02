import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal_status_flow.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/collector/meal_status_collector.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/bolus_then_wait_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/pending_notifications_controller.dart';

void main() {
  final now = DateTime(2026, 11, 1, 12);
  late DatabaseImpl db;
  late ProviderContainer container;
  late WorkflowScheduler scheduler;
  late MealMonitorTask task;
  late MealStatusCollector collector;
  late PendingNotificationsController notifications;
  var started = false;
  var sequence = 0;

  Future<int> meal(
    String status, {
    DateTime? at,
    String purpose = 'meal',
  }) async {
    final id = await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Meal ${++sequence}',
            plannedAt: now
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            purpose: Value(purpose),
          ),
        );
    await db.mealDao.updateMealStatus(
      id,
      status,
      occurredAt: at ?? now.subtract(const Duration(minutes: 20)),
    );
    return id;
  }

  void start() {
    final context = scheduler.createContext(container);
    scheduler.startTask(task, context);
    collector.start(CollectorContext.fromRuntimeContext(context));
    started = true;
  }

  setUp(() {
    started = false;
    sequence = 0;
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = PendingNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    scheduler = WorkflowScheduler();
    task = MealMonitorTask();
    collector = MealStatusCollector();
  });

  tearDown(() async {
    if (started) await collector.dispose();
    await scheduler.dispose();
    container.dispose();
    await db.close();
  });

  for (final status in mealStatusesBlockingAnotherMealActivation) {
    test(
      'cold service restores $status after a newer unrelated summary',
      () async {
        await withClock(Clock.fixed(now), () async {
          final active = await meal(status);
          final completed = await meal('summarized', at: now);
          final events = scheduler.openEventInbox<MealStatusChangedEvent>();
          start();
          await pumpEventQueue(times: 100);
          final restored = events.drain();
          expect(
            restored.where((event) => event.mealId == active),
            hasLength(1),
          );
          expect(restored.first.toJson()['kind'], status);
          final expected = switch (status) {
            'waiting-for-bolus' => isA<WaitForBolusExecutor>(),
            'bolused-waiting' => isA<BolusThenWaitExecutor>(),
            _ => isA<DetectFinishedEatingExecutor>(),
          };
          expect(task.state, expected);
          expect((await db.mealDao.getMealById(active))!.status, status);
          expect(
            (await db.mealDao.getMealById(completed))!.status,
            'summarized',
          );
        });
      },
    );
  }

  test(
    'initial active state is emitted only once when it is the latest history',
    () async {
      await withClock(Clock.fixed(now), () async {
        final active = await meal('waited-eating');
        final events = scheduler.openEventInbox<MealStatusChangedEvent>();
        start();
        await pumpEventQueue(times: 100);
        expect(events.drain().map((event) => event.mealId), [active]);
        expect(task.state, isA<DetectFinishedEatingExecutor>());
      });
    },
  );

  test(
    'interruption committed while startup reads are pending prevents restoration',
    () async {
      await withClock(Clock.fixed(now), () async {
        final active = await meal('eating');
        await meal('summarized', at: now);
        final events = scheduler.openEventInbox<MealStatusChangedEvent>();
        final transactionStarted = Completer<void>();
        final commit = Completer<void>();
        final interruption = db.transaction(() async {
          transactionStarted.complete();
          await commit.future;
          await db.mealDao.interruptMeal(active);
        });
        await transactionStarted.future;
        start();
        await pumpEventQueue();
        commit.complete();
        await interruption;
        await pumpEventQueue(times: 100);
        expect(events.drain().whereType<MealStartedEatingEvent>(), isEmpty);
        expect(task.state, isA<MealMonitorStateIdle>());
        expect((await db.mealDao.getMealById(active))!.status, 'interrupted');
        expect(notifications.shownEvents, isEmpty);
      });
    },
  );

  test(
    'expired bolus wait uses recorded start even after a later meal edit',
    () async {
      await withClock(Clock.fixed(now), () async {
        final active = await meal('bolused-waiting');
        await db.customStatement(
          '''INSERT INTO meal_advisor_result
        (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored)
        VALUES (?, 'manual', 15, 15, 0)''',
          [active],
        );
        await (db.update(db.meal)..where((row) => row.id.equals(active))).write(
          MealCompanion(updatedAt: Value(now.millisecondsSinceEpoch)),
        );
        await meal('summarized', at: now);
        start();
        await pumpEventQueue(times: 100);
        final reminder = notifications.shownEvents
            .whereType<EatNowNotificationEvent>()
            .single;
        expect(reminder.mealId, active);
        expect(reminder.minutes, 20);
        expect(
          (await db.mealDao.getMealById(active))!.status,
          'bolused-waiting',
        );
      });
    },
  );

  test(
    'cold restore ignores low treatments and terminal ordinary meals',
    () async {
      await withClock(Clock.fixed(now), () async {
        await meal('eating', purpose: 'lowTreatment');
        await meal('interrupted');
        await meal('summarized', at: now);
        final events = scheduler.openEventInbox<MealStatusChangedEvent>();
        start();
        await pumpEventQueue(times: 100);
        expect(events.drain().whereType<MealStartedEatingEvent>(), isEmpty);
        expect(task.state, isA<MealMonitorStateIdle>());
        expect(notifications.shownEvents, isEmpty);
      });
    },
  );
}
