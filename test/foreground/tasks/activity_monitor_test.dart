import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/activity_finished_response_event.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_finished_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/internal/activity_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_task.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/monitor_active_activity_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/monitor_until_activity_executor.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  LogRuntimeConfig.configure(isUnitTest: true, enableBuffer: false);

  group('ActivityMonitorTask', () {
    test('waits for planned activity and asks at planned end', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      var now = DateTime(2026, 3, 23, 12);
      final startsAt = now.add(const Duration(minutes: 10));
      await _seedActivityLog(db, startsAt: startsAt, durationMinutes: 30);

      await withClock(Clock(() => now), () async {
        final notifications = FakeNotificationsController();
        final harness = _startHarness(db, notifications);
        addTearDown(harness.dispose);

        final task = ActivityMonitorTask();
        _runTask(task, harness);
        await _settle();

        expect(task.state, isA<MonitorUntilActivityExecutor>());
        expect(notifications.shownEvents, isEmpty);

        now = startsAt.subtract(const Duration(minutes: 1));
        await _dispatchTick(harness, now);

        expect(task.state, isA<MonitorUntilActivityExecutor>());
        expect(notifications.shownEvents, isEmpty);

        now = startsAt;
        await _dispatchTick(harness, now);

        expect(task.state, isA<MonitorActiveActivityExecutor>());
        expect(notifications.shownEvents, isEmpty);

        now = startsAt.add(const Duration(minutes: 29));
        await _dispatchTick(harness, now);

        expect(notifications.shownEvents, isEmpty);

        now = startsAt.add(const Duration(minutes: 30));
        await _dispatchTick(harness, now);

        expect(notifications.shownEvents, hasLength(1));
        final event = notifications.shownEvents.single;
        expect(event, isA<ActivityFinishedNotificationEvent>());
        expect((event as ActivityFinishedNotificationEvent).activityLogId, 1);
      });
    });

    test('confirmation ends active activity and returns to idle', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      var now = DateTime(2026, 3, 23, 12);
      final startsAt = now.subtract(const Duration(minutes: 10));
      await _seedActivityLog(db, startsAt: startsAt, durationMinutes: 15);

      await withClock(Clock(() => now), () async {
        final notifications = FakeNotificationsController();
        final harness = _startHarness(db, notifications);
        addTearDown(harness.dispose);

        final task = ActivityMonitorTask();
        _runTask(task, harness);
        await _settle();

        expect(task.state, isA<MonitorActiveActivityExecutor>());

        now = startsAt.add(const Duration(minutes: 15));
        await _dispatchTick(harness, now);

        expect(notifications.shownEvents, hasLength(1));

        harness.dispatchEventToTask(
          task,
          ActivityFinishedResponseEvent.agree(activityLogId: 1),
        );
        await _settle();

        final log = await db.activityDao.getActivityLogById(1);
        expect(log.endedAt, now.millisecondsSinceEpoch);
        expect(notifications.cancelAllCalled, isTrue);
        expect(task.state, isA<ActivityMonitorStateIdle>());
      });
    });

    test('dismiss keeps activity active until manual stop event', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      var now = DateTime(2026, 3, 23, 12);
      final startsAt = now.subtract(const Duration(minutes: 5));
      await _seedActivityLog(db, startsAt: startsAt, durationMinutes: 5);

      await withClock(Clock(() => now), () async {
        final notifications = FakeNotificationsController();
        final harness = _startHarness(db, notifications);
        addTearDown(harness.dispose);

        final task = ActivityMonitorTask();
        _runTask(task, harness);
        await _settle();

        await _dispatchTick(harness, now);
        expect(notifications.shownEvents, hasLength(1));

        harness.dispatchEventToTask(
          task,
          ActivityFinishedResponseEvent.dismiss(activityLogId: 1),
        );
        await _settle();

        var log = await db.activityDao.getActivityLogById(1);
        expect(log.endedAt, isNull);

        now = now.add(const Duration(minutes: 2));
        await db.activityDao.updateActivityLog(
          ActivityLogCompanion(
            id: const Value(1),
            activityId: const Value(1),
            startedAt: Value(startsAt.millisecondsSinceEpoch),
            endedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
        harness.dispatchEventToTask(
          task,
          ActivityStoppedEvent(
            activityLogId: 1,
            activityId: 1,
            startsAt: startsAt,
            stoppedAt: now,
          ),
        );
        await _settle();

        log = await db.activityDao.getActivityLogById(1);
        expect(log.endedAt, now.millisecondsSinceEpoch);
        expect(task.state, isA<ActivityMonitorStateIdle>());
      });
    });

    test('cancelled planned activity returns to idle', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime(2026, 3, 23, 12);
      final startsAt = now.add(const Duration(minutes: 30));
      await _seedActivityLog(db, startsAt: startsAt, durationMinutes: 30);

      await withClock(Clock(() => now), () async {
        final notifications = FakeNotificationsController();
        final harness = _startHarness(db, notifications);
        addTearDown(harness.dispose);

        final task = ActivityMonitorTask();
        _runTask(task, harness);
        await _settle();

        expect(task.state, isA<MonitorUntilActivityExecutor>());

        await db.activityDao.removeActivityLog(
          ActivityLogCompanion(id: const Value(1)),
        );
        harness.dispatchEventToTask(
          task,
          ActivityCancelledEvent(
            activityLogId: 1,
            activityId: 1,
            startsAt: startsAt,
          ),
        );
        await _settle();

        expect(notifications.shownEvents, isEmpty);
        expect(task.state, isA<ActivityMonitorStateIdle>());
      });
    });
  });
}

void _runTask(ActivityMonitorTask task, FakeRuntimeHarness harness) {
  unawaited(
    task.run(harness.runtimeContext).catchError((Object error) {
      if (error is! TaskCancelledException) {
        throw error;
      }
    }),
  );
}

FakeRuntimeHarness _startHarness(
  DatabaseImpl db,
  FakeNotificationsController notifications,
) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notificationsControllerForegroundProvider.overrideWithValue(
        notifications,
      ),
    ],
  );

  return FakeRuntimeHarness(container: container);
}

Future<void> _seedActivityLog(
  DatabaseImpl db, {
  required DateTime startsAt,
  required int durationMinutes,
}) async {
  await db.customInsert(
    '''
    INSERT INTO activity (
      id,
      name,
      percentage_pre,
      percentage_post,
      duration_minutes
    ) VALUES (1, 'Spacer', 10, 20, ?)
    ''',
    variables: [Variable<int>(durationMinutes)],
  );

  await db.customInsert(
    '''
    INSERT INTO activity_log (
      id,
      activity_id,
      started_at
    ) VALUES (1, 1, ?)
    ''',
    variables: [Variable<int>(startsAt.millisecondsSinceEpoch)],
  );
}

Future<void> _dispatchTick(FakeRuntimeHarness harness, DateTime now) async {
  harness.dispatchTick(now);
  await _settle();
}

Future<void> _settle({int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
