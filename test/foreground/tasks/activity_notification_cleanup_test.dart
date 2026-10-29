import 'package:clock/clock.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_finished_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_context.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/finish_activity_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/executors/new_activity_check_executor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/fake_runtime_harness.dart';
import '../utils/pending_notifications_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late DatabaseImpl db;
  late TempTargetService service;
  late PendingNotificationsController notifications;
  late FakeRuntimeHarness harness;

  setUp(() async {
    now = DateTime(2026, 10, 29, 16);
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'test-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    service = TempTargetService(
      preferences: () async => prefs,
      database: () => db,
      writer: NightscoutTempTargetWriter(
        client: MockClient((_) async {
          throw StateError('Notification cleanup must not send treatments');
        }),
      ),
    );
    notifications = PendingNotificationsController();
    harness = FakeRuntimeHarness(
      container: ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((_) async => prefs),
          databaseProvider.overrideWithValue(db),
          tempTargetServiceProvider.overrideWithValue(service),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
    harness.container.dispose();
    await db.close();
  });

  Future<int> activity(String name, DateTime startsAt) async {
    final activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: name,
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
    return db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: startsAt.millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> deliver(TempTargetNotificationEvent offer) async {
    await notifications.show(offer);
    await service.markDelivered(offer.requestId!);
  }

  test(
    'finishing one activity preserves delivered activity and meal consent without redelivery',
    () => withClock(Clock(() => now), () async {
      final firstStart = now.subtract(const Duration(minutes: 30));
      final first = await activity('Running', firstStart);
      final next = await activity('Jujitsu', now.add(const Duration(hours: 1)));
      final meal = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Dinner',
              plannedAt: now
                  .add(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
            ),
          );
      final firstOffer = (await service.activityOffer(first))!;
      final nextOffer = (await service.activityOffer(next))!;
      final mealOffer = (await service.prepare(
        TempTargetNotificationEvent.meal(entityId: meal),
      ))!;
      for (final offer in [firstOffer, nextOffer, mealOffer]) {
        await deliver(offer);
      }
      final finished = ActivityFinishedNotificationEvent(
        activityLogId: first,
        activityName: 'Running',
      );
      await notifications.show(finished);
      final shownCount = notifications.shownEvents.length;

      now = now.add(const Duration(minutes: 20));
      await db.activityDao.finishActivityLogIfOpen(first, firstStart, now);
      final context = ActivityMonitorContext(activityLogId: first);
      final nextState = await const FinishActivityExecutor().execute(
        harness.runtimeContext,
        context,
      );

      expect(nextState, isA<NewActivityCheckExecutor>());
      expect(context.activityLogId, isNull);
      expect(notifications.cancelAllCalled, isFalse);
      expect(notifications.contains(firstOffer), isFalse);
      expect(notifications.contains(finished), isFalse);
      expect(notifications.contains(nextOffer), isTrue);
      expect(notifications.contains(mealOffer), isTrue);
      expect(notifications.shownEvents, hasLength(shownCount));
      final operations = TempTargetOperationRepository(db);
      for (final offer in [nextOffer, mealOffer]) {
        expect(
          (await operations.get(offer.requestId!))!.status,
          TempTargetOperationStatus.awaitingConsent,
        );
      }
    }),
  );

  test(
    'cleanup cancels only the occurrence belonging to the finished activity',
    () => withClock(Clock(() => now), () async {
      final start = now.subtract(const Duration(minutes: 30));
      final first = await activity('Running', start);
      final nextStart = now.add(const Duration(hours: 2));
      final next = await activity('Jujitsu', nextStart);
      Future<int> occurrence(int logId, DateTime startsAt) async {
        final log = await db.activityDao.getActivityLogById(logId);
        return db
            .into(db.activityOccurrence)
            .insert(
              ActivityOccurrenceCompanion.insert(
                activityId: log.activityId,
                startedAt: startsAt.millisecondsSinceEpoch,
                actionAt: startsAt.millisecondsSinceEpoch,
                confirmationMode: 'automatic',
                durationMinutes: const Value(60),
                activityLogId: Value(logId),
              ),
            );
      }

      final firstOccurrence = await occurrence(first, start);
      final nextOccurrence = await occurrence(next, nextStart);
      final current = ActivityScheduleNotificationEvent(
        occurrenceId: firstOccurrence,
        activityName: 'Running',
        startsAt: start,
      );
      final later = ActivityScheduleNotificationEvent(
        occurrenceId: nextOccurrence,
        activityName: 'Jujitsu',
        startsAt: nextStart,
      );
      final mealReminder = EatNowNotificationEvent(mealId: 42, minutes: 15);
      for (final notification in [current, later, mealReminder]) {
        await notifications.show(notification);
      }
      await db.activityDao.finishActivityLogIfOpen(first, start, now);

      await const FinishActivityExecutor().execute(
        harness.runtimeContext,
        ActivityMonitorContext(activityLogId: first),
      );

      expect(notifications.contains(current), isFalse);
      expect(notifications.contains(later), isTrue);
      expect(notifications.contains(mealReminder), isTrue);
      expect(notifications.cancelAllCalled, isFalse);
    }),
  );

  test(
    'an empty monitor context does not cancel unrelated notifications',
    () => withClock(Clock(() => now), () async {
      final reminder = EatNowNotificationEvent(mealId: 42, minutes: 15);
      await notifications.show(reminder);

      await const FinishActivityExecutor().execute(
        harness.runtimeContext,
        ActivityMonitorContext(),
      );

      expect(notifications.contains(reminder), isTrue);
      expect(notifications.cancelledIds, isEmpty);
      expect(notifications.cancelAllCalled, isFalse);
    }),
  );
}
