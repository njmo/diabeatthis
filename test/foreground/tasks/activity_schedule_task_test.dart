import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/activity_schedule_response_event.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_schedule_task.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/fake_notifications_controller.dart';

Future<void> settle() async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late WorkflowScheduler scheduler;
  late FakeNotificationsController notifications;
  late ActivityScheduleService service;
  var now = DateTime(2026, 10, 28, 6);

  setUp(() async {
    now = DateTime(2026, 10, 28, 6);
    db = DatabaseImpl(NativeDatabase.memory());
    notifications = FakeNotificationsController();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationsControllerForegroundProvider.overrideWithValue(
          notifications,
        ),
      ],
    );
    service = container.read(activityScheduleServiceProvider);
    scheduler = WorkflowScheduler();
    await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'PE',
            percentagePre: 0,
            percentagePost: 0,
          ),
        );
  });
  tearDown(() async {
    await scheduler.dispose();
    container.dispose();
    await db.close();
  });

  Future<void> rule(int hour, String mode) => service.save(
    activityId: 1,
    weekdays: {3},
    startMinute: hour * 60,
    durationMinutes: 45,
    mode: mode,
    validFrom: DateTime(2026, 10, 28),
  );

  void start() => scheduler.startTask(
    const ActivityScheduleTask(),
    scheduler.createContext(container),
  );

  test(
    'asks at 90 minutes, does not block the afternoon, and does not repeat after restart',
    () => withClock(Clock(() => now), () async {
      await rule(8, 'before');
      await rule(17, 'before');
      start();
      await settle();
      expect(notifications.shownEvents, isEmpty);
      now = DateTime(2026, 10, 28, 6, 30);
      scheduler.tick(now);
      await settle();
      expect(
        notifications.shownEvents
            .whereType<ActivityScheduleNotificationEvent>()
            .length,
        1,
      );
      expect(await db.select(db.activityLog).get(), isEmpty);

      now = DateTime(2026, 10, 28, 15, 30);
      scheduler.tick(now);
      await settle();
      final prompts = notifications.shownEvents
          .whereType<ActivityScheduleNotificationEvent>()
          .toList();
      expect(prompts.length, 2);
      scheduler.emitEvent(
        ActivityScheduleResponseEvent.agree(
          occurrenceId: prompts.last.occurrenceId,
        ),
      );
      await settle();
      expect(await db.select(db.activityLog).get(), hasLength(1));
      expect(
        notifications.shownEvents.whereType<TempTargetNotificationEvent>(),
        hasLength(1),
      );
      await scheduler.dispose();
      scheduler = WorkflowScheduler();
      start();
      await settle();
      expect(
        notifications.shownEvents
            .whereType<ActivityScheduleNotificationEvent>(),
        hasLength(2),
      );
      expect(
        notifications.shownEvents.whereType<TempTargetNotificationEvent>(),
        hasLength(1),
      );
    }),
  );

  test(
    'automatic planning needs no answer and requests a target',
    () => withClock(Clock(() => now), () async {
      await rule(8, 'automatic');
      start();
      await settle();
      now = DateTime(2026, 10, 28, 6, 30);
      scheduler.tick(now);
      await settle();
      expect(
        notifications.shownEvents
            .whereType<ActivityScheduleNotificationEvent>(),
        isEmpty,
      );
      expect(
        notifications.shownEvents.whereType<TempTargetNotificationEvent>(),
        hasLength(1),
      );
      final logs = await db.select(db.activityLog).get();
      expect(logs, hasLength(1));
      expect(
        logs.single.startedAt,
        DateTime(2026, 10, 28, 8).millisecondsSinceEpoch,
      );
    }),
  );

  test(
    'previous evening confirmation reserves the morning and defers the target',
    () => withClock(Clock(() => now), () async {
      now = DateTime(2026, 10, 27, 19);
      await rule(8, 'previous_day');
      start();
      await settle();
      final prompt = notifications.shownEvents
          .whereType<ActivityScheduleNotificationEvent>()
          .single;
      scheduler.emitEvent(
        ActivityScheduleResponseEvent.agree(occurrenceId: prompt.occurrenceId),
      );
      await settle();
      expect(await db.select(db.activityLog).get(), hasLength(1));
      expect(
        notifications.shownEvents.whereType<TempTargetNotificationEvent>(),
        isEmpty,
      );
      now = DateTime(2026, 10, 28, 6, 30);
      scheduler.tick(now);
      await settle();
      expect(
        notifications.shownEvents
            .whereType<ActivityScheduleNotificationEvent>(),
        hasLength(1),
      );
      expect(
        notifications.shownEvents.whereType<TempTargetNotificationEvent>(),
        hasLength(1),
      );
    }),
  );
}
