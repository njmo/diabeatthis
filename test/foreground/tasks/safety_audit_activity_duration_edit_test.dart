import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_task.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/common/wait_for_condition.dart';
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'an open activity follows its edited default duration',
    () => withClock(Clock(() => now), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final startsAt = DateTime(2026, 11, 3, 12);
      now = startsAt;
      await db.customInsert('''
        INSERT INTO activity (
          id, name, percentage_pre, percentage_post, duration_minutes
        ) VALUES (1, 'Run', 0, 0, 30)
        ''');
      await db.customInsert('''
        INSERT INTO activity_log (id, activity_id, started_at)
        VALUES (1, 1, ${startsAt.millisecondsSinceEpoch})
        ''');
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(harness.dispose);
      final task = ActivityMonitorTask();
      final running = task.run(harness.runtimeContext).catchError((
        Object error,
      ) {
        if (error is! TaskCancelledException) throw error;
      });
      addTearDown(() async {
        harness.cancel();
        await running;
      });
      await waitForCondition(
        () => harness.pendingDeadlines.contains(
          startsAt.add(const Duration(minutes: 30)),
        ),
        description: 'the activity monitor to wait for its original end',
      );

      await (db.update(db.activity)..where((row) => row.id.equals(1))).write(
        const ActivityCompanion(durationMinutes: Value(60)),
      );
      now = startsAt.add(const Duration(minutes: 30));
      harness.dispatchTick(now);
      // Wait for the old deadline to be processed and the edited deadline to
      // be registered before asserting that the activity remains open.
      await waitForCondition(
        () => harness.pendingDeadlines.contains(
          startsAt.add(const Duration(minutes: 60)),
        ),
        description: 'the activity monitor to adopt the edited duration',
      );
      expect((await db.activityDao.getActivityLogById(1)).endedAt, isNull);

      now = startsAt.add(const Duration(minutes: 60));
      harness.dispatchTick(now);
      await waitForCondition(
        () async =>
            (await db.activityDao.getActivityLogById(1)).endedAt != null,
        description: 'the activity to finish at its edited deadline',
      );
      expect(
        (await db.activityDao.getActivityLogById(1)).endedAt,
        now.millisecondsSinceEpoch,
      );
    }),
  );
}

late DateTime now;
