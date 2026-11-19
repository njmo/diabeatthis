import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_schedule_task.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';

class PausedActivityNotifications extends FakeNotificationsController {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> show(NotificationEvent event) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await super.show(event);
  }
}

class PausedActivityCancellation extends FakeNotificationsController {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> cancel(int id, {String? tag}) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    await super.cancel(id);
  }
}

void main() {
  test(
    'move during notification delivery resets the new slot instead of suppressing its prompt',
    () => withClock(Clock.fixed(DateTime(2026, 11, 11, 16)), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final notifications = PausedActivityNotifications();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final scheduler = WorkflowScheduler();
      addTearDown(() async {
        await scheduler.dispose();
        container.dispose();
        await db.close();
      });
      await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Training',
              percentagePre: 20,
              percentagePost: 30,
            ),
          );
      final service = container.read(activityScheduleServiceProvider);
      await service.save(
        activityId: 1,
        weekdays: {3},
        startMinute: 17 * 60,
        durationMinutes: 43,
        mode: 'before',
        validFrom: DateTime(2026, 11, 11),
      );
      final original = (await db.select(db.activityOccurrence).get()).first;
      scheduler.startTask(
        const ActivityScheduleTask(),
        scheduler.createContext(container),
      );
      await notifications.entered.future;
      final destination = DateTime(2026, 11, 11, 20);
      final moving = service.move(original.id, destination);
      notifications.release.complete();
      await moving;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final row = (await db.select(db.activityOccurrence).get()).firstWhere(
        (row) => row.id == original.id,
      );
      expect(row.id, original.id);
      expect(row.startedAt, destination.millisecondsSinceEpoch);
      expect(row.askedAt, isNull);
      expect(row.targetRequestedAt, isNull);
      expect(row.status, 'pending');
      expect(notifications.cancelledIds, isNotEmpty);
    }),
  );
  test(
    'old cancellation finishes before the moved due prompt can be shown',
    () => withClock(Clock.fixed(DateTime(2026, 11, 11, 16)), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final notifications = PausedActivityCancellation();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final scheduler = WorkflowScheduler();
      addTearDown(() async {
        await scheduler.dispose();
        container.dispose();
        await db.close();
      });
      await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Training',
              percentagePre: 20,
              percentagePost: 30,
            ),
          );
      final service = container.read(activityScheduleServiceProvider);
      await service.save(
        activityId: 1,
        weekdays: {3},
        startMinute: 17 * 60,
        durationMinutes: 43,
        mode: 'before',
        validFrom: DateTime(2026, 11, 11),
      );
      final original = (await db.select(db.activityOccurrence).get()).first;
      final destination = DateTime(2026, 11, 11, 17, 10);
      final moving = service.move(original.id, destination);
      await notifications.entered.future;
      scheduler.startTask(
        const ActivityScheduleTask(),
        scheduler.createContext(container),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(notifications.shownEvents, isEmpty);
      notifications.release.complete();
      await moving;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final row = (await db.select(db.activityOccurrence).get()).firstWhere(
        (r) => r.id == original.id,
      );
      expect(row.askedAt, isNotNull);
      expect(notifications.shownEvents, hasLength(1));
      expect(notifications.cancelledIds, hasLength(1));
    }),
  );

  test(
    'durable caregiver cleanup runs offline before replacement prompt delivery',
    () => withClock(Clock.fixed(DateTime(2026, 11, 11, 16)), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      final scheduler = WorkflowScheduler();
      addTearDown(() async {
        await scheduler.dispose();
        container.dispose();
        await db.close();
      });
      await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Training',
              percentagePre: 20,
              percentagePost: 30,
            ),
          );
      final service = container.read(activityScheduleServiceProvider);
      await service.save(
        activityId: 1,
        weekdays: {3},
        startMinute: 17 * 60,
        durationMinutes: 43,
        mode: 'before',
        validFrom: DateTime(2026, 11, 11),
      );
      final row = (await db.select(db.activityOccurrence).get()).first;
      await db.customStatement(
        "INSERT INTO family_plan_journal(operation_id,claim_token,owner_uid,source_id,outcome,required_revisions,cancel_occurrence_id) VALUES('move','claim','child','source','applied','[]',?)",
        [row.id],
      );
      scheduler.startTask(
        const ActivityScheduleTask(),
        scheduler.createContext(container),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifications.cancelledIds, hasLength(1));
      expect(
        (await db
                .customSelect(
                  "SELECT notification_cleared FROM family_plan_journal WHERE operation_id='move'",
                )
                .getSingle())
            .read<int>('notification_cleared'),
        1,
      );
      expect(notifications.shownEvents, hasLength(1));
      expect(
        (await db.select(db.activityOccurrence).get()).first.askedAt,
        isNotNull,
      );
    }),
  );
}
