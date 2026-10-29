import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/domain/model/meal.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/bolus_reminder_helper.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
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
  final now = DateTime(2026, 10, 29, 16);
  late DatabaseImpl db;
  late TempTargetService service;
  late PendingNotificationsController notifications;
  late FakeRuntimeHarness harness;
  late int mealId;
  late TempTargetNotificationEvent ownOffer;
  late List<TempTargetNotificationEvent> unrelatedOffers;

  setUp(() async {
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
    await withClock(Clock.fixed(now), () async {
      Future<int> meal(String name) => db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: name,
              plannedAt: now
                  .add(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
            ),
          );
      mealId = await meal('Current meal');
      final nextMeal = await meal('Next meal');
      final activityId = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Jujitsu',
              percentagePre: 0,
              percentagePost: 0,
              durationMinutes: const Value(60),
            ),
          );
      final activityLogId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: now
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
            ),
          );
      ownOffer = (await service.prepare(
        TempTargetNotificationEvent.meal(entityId: mealId),
      ))!;
      unrelatedOffers = [
        (await service.prepare(
          TempTargetNotificationEvent.meal(entityId: nextMeal),
        ))!,
        (await service.activityOffer(activityLogId))!,
      ];
      for (final offer in [ownOffer, ...unrelatedOffers]) {
        await notifications.show(offer);
        await service.markDelivered(offer.requestId!);
      }
    });
  });

  tearDown(() async {
    await harness.dispose();
    harness.container.dispose();
    await db.close();
  });

  Future<void> expectConsentPreserved(TempTargetNotificationEvent offer) async {
    expect(notifications.contains(offer), isTrue);
    expect(
      (await TempTargetOperationRepository(db).get(offer.requestId!))!.status,
      TempTargetOperationStatus.awaitingConsent,
    );
  }

  test(
    'meal finalization preserves other meal and activity consent while scheduling its summary',
    () => withClock(Clock.fixed(now), () async {
      final currentReminder = EatNowNotificationEvent(
        mealId: mealId,
        minutes: 15,
      );
      await notifications.show(currentReminder);
      final before = notifications.shownEvents.length;
      await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
        const MealCompanion(status: Value('eaten-bolused')),
      );

      await FinalizeMealExecutor().execute(
        harness.runtimeContext,
        MealMonitorContext(
          activeMeal: domain.Meal(id: mealId, name: 'Current meal'),
        ),
      );

      expect(notifications.contains(ownOffer), isFalse);
      expect(notifications.contains(currentReminder), isFalse);
      expect(notifications.cancelAllCalled, isFalse);
      for (final offer in unrelatedOffers) {
        await expectConsentPreserved(offer);
      }
      expect(notifications.shownEvents, hasLength(before));
      final scheduled = notifications.scheduledEvents.single;
      expect(scheduled.event, isA<MealSummaryReminderNotificationEvent>());
      expect(
        (scheduled.event as MealSummaryReminderNotificationEvent).mealId,
        mealId,
      );
      expect(scheduled.duration, FinalizeMealExecutor.summaryReminderDelay);
    }),
  );

  test(
    'bolus reminder refresh and dismissal preserve all valid pending consent questions',
    () => withClock(Clock.fixed(now), () async {
      final reminder = BolusReminderHelper().remindUntilBolusRecorded(
        harness.runtimeContext,
        notifications,
        mealId,
        carbs: 20,
      );
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      for (final offer in [ownOffer, ...unrelatedOffers]) {
        await expectConsentPreserved(offer);
      }
      final current = notifications.shownEvents
          .whereType<MealSuggestionNotificationEvent>()
          .single;
      expect(notifications.contains(current), isTrue);

      harness.dispatchEvent(MealSuggestionResponseEvent.skip(mealId: mealId));
      expect(await reminder, isFalse);

      expect(notifications.contains(current), isFalse);
      expect(notifications.cancelAllCalled, isFalse);
      for (final offer in [ownOffer, ...unrelatedOffers]) {
        await expectConsentPreserved(offer);
      }
    }),
  );
}
