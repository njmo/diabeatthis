import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/meal_summary_reminder_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/temp_target_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/temp_target_type.dart';
import 'package:diabeatthis/core/domain/model/bolus_calculator_result.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/core/notifications/definitions/event/meal_summary_reminder_notification_definition.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_action_type.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/bolus_then_wait_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/meal_monitor_state_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/new_meal_check_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void withFakeClock(FakeAsync async, DateTime start, void Function() body) {
  withClock(Clock(() => start.add(async.elapsed)), body);
}

BolusWizard testBolusWizard({
  DateTime? createdAt,
  int glucose = 100,
  double carbs = 10,
  double insulin = 1,
  String? nightscoutObjectId,
  String? notes,
}) {
  return BolusWizard(
    nightscoutObjectId: nightscoutObjectId,
    createdAt: createdAt ?? clock.now(),
    date: createdAt ?? clock.now(),
    glucose: glucose,
    units: 'mg/dl',
    notes: notes,
    calculatorResult: testBolusCalculatorResult(
      carbs: carbs,
      totalInsulin: insulin,
    ),
  );
}

BolusCalculatorResult testBolusCalculatorResult({
  double? carbs,
  double? totalInsulin,
}) {
  return BolusCalculatorResult(
    id: null,
    basalIob: null,
    bolusIob: null,
    carbs: carbs,
    carbsInsulin: null,
    cob: null,
    cobInsulin: null,
    dateCreated: null,
    glucoseDifference: null,
    glucoseInsulin: null,
    glucoseTrend: null,
    glucoseValue: null,
    ic: null,
    isf: null,
    note: null,
    otherCorrection: null,
    percentageCorrection: null,
    profileName: null,
    superbolusInsulin: null,
    targetBGHigh: null,
    targetBGLow: null,
    timestamp: null,
    totalInsulin: totalInsulin,
    trendInsulin: null,
    utcOffset: null,
    version: null,
    wasBasalIOBUsed: null,
    wasBolusIOBUsed: null,
    wasCOBUsed: null,
    wasGlucoseUsed: null,
    wasSuperbolusUsed: null,
    wasTempTargetUsed: null,
    wasTrendUsed: null,
    wereCarbsUsed: null,
  );
}

void emitDeviceStatus(
  FakeRuntimeHarness harness,
  MealMonitorTask task,
  ProviderContainer container,
  DeviceStatus deviceStatus,
) {
  harness.dispatchEventToTask(
    task,
    DataAvailableEvent<DeviceStatus>(deviceStatus),
  );
  container.read(deviceStatusValueProvider.notifier).update(deviceStatus);
}

final fakeNotifications = FakeNotificationsController();

final parentContainer = ProviderContainer(
  overrides: [
    notificationsControllerForegroundProvider.overrideWithValue(
      fakeNotifications,
    ),
  ],
);

void _settle(FakeAsync async, {int times = 10}) {
  for (var i = 0; i < times; i++) {
    async.flushMicrotasks();
  }
}

void _advanceTime(
  FakeRuntimeHarness harness,
  FakeAsync async,
  Duration duration,
) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds <= 0) {
    harness.dispatchTick(clock.now());
    _settle(async);
    return;
  }

  const stepSeconds = 30;
  var remainingSeconds = totalSeconds;

  while (remainingSeconds > 0) {
    final chunkSeconds = remainingSeconds >= stepSeconds
        ? stepSeconds
        : remainingSeconds;
    async.elapse(Duration(seconds: chunkSeconds));
    harness.dispatchTick(clock.now());
    _settle(async);
    remainingSeconds -= chunkSeconds;
  }
}

void _advanceMinutes(FakeRuntimeHarness harness, FakeAsync async, int minutes) {
  _advanceTime(harness, async, Duration(minutes: minutes));
}

class UpdateMealSpy {
  final calls = <(Meal, String)>[];

  Future<void> call(Meal meal, String status) async {
    calls.add((meal, status));
  }
}

void main() {
  LogRuntimeConfig.configure(isUnitTest: true, enableBuffer: false);

  group("MealMonitorTask tests", () {
    setUp(() {
      fakeNotifications.shownEvents.clear();
      fakeNotifications.scheduledEvents.clear();
      fakeNotifications.cancelledIds.clear();
      fakeNotifications.cancelAllCalled = false;
      parentContainer.read(latestBolusWizardProvider.notifier).clear();
    });

    test('parses eating-extra meal status as add-on eating event', () {
      final event = MealStatusChangedEvent.fromJson({
        'kind': 'eating-extra',
        'mealId': 1,
      });

      expect(event, isA<MealEatingExtraEvent>());
      expect(event.mealId, 1);
    });

    test('parses eaten-extra meal status as add-on finished event', () {
      final event = MealStatusChangedEvent.fromJson({
        'kind': 'eaten-extra',
        'mealId': 1,
      });

      expect(event, isA<MealFinishedEatingExtraEvent>());
      expect(event.mealId, 1);
    });

    test('summary reminder notification has plan and acknowledge actions', () {
      final actionTypes = mealSummaryReminderNotificationDefinition.actions.map(
        (action) => action.type,
      );

      expect(actionTypes, [
        NotificationActionType.agree,
        NotificationActionType.dismiss,
      ]);
    });

    test('temp target notification supports meal and activity sources', () {
      final meal = TempTargetNotificationEvent.meal(entityId: 1);
      final activity = TempTargetNotificationEvent.activity(entityId: 2);

      expect(meal.entityId, 1);
      expect(meal.targetType, TempTargetType.meal);
      expect(meal.tempTargetString, 'Meal');
      expect(activity.entityId, 2);
      expect(activity.targetType, TempTargetType.activity);
      expect(activity.tempTargetString, 'Activity');

      final activityPayload =
          activity.toPayload()['action_data']! as Map<String, Object?>;

      expect(activityPayload['entityId'], 2);
      expect(activityPayload['targetType'], TempTargetType.activity);
    });

    test('temp target response accepts meal payload', () {
      final event = TempTargetResponseEvent.fromJson({
        'action': 'agree',
        'entityId': 1,
        'targetType': TempTargetType.meal,
        'tempTargetString': 'Meal',
      });

      expect(event.entityId, 1);
      expect(event.targetType, TempTargetType.meal);
    });

    test('temp target response accepts activity source payload', () {
      final event = TempTargetResponseEvent.fromJson({
        'action': 'agree',
        'entityId': 2,
        'targetType': TempTargetType.activity,
        'tempTargetString': 'Activity',
      });

      expect(event.entityId, 2);
      expect(event.targetType, TempTargetType.activity);
    });

    test('summary reminder action saves planned amount as consumed', () async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedPlannedMeal(db);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final harness = FakeRuntimeHarness(container: container);
      NotificationResponseEventHandler().handle(
        NotificationResponseEvent.mealSummaryReminderResponse(
          data: MealSummaryReminderResponseEvent.agree(mealId: 1),
        ),
        harness.runtimeContext,
      );

      await _flushMicrotasks();

      final meal = await db.mealDao.getMealById(1);
      final snapshots = await db.select(db.mealSnapshot).get();

      expect(meal?.status, 'summarized');
      expect(snapshots, hasLength(1));
      expect(snapshots.single.snapshotType, 'consumed');
      expect(snapshots.single.totalNetCarbsG, 15);
    });

    test('summary reminder ok action leaves meal unchanged', () async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedPlannedMeal(db);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final harness = FakeRuntimeHarness(container: container);
      NotificationResponseEventHandler().handle(
        NotificationResponseEvent.mealSummaryReminderResponse(
          data: MealSummaryReminderResponseEvent.dismiss(mealId: 1),
        ),
        harness.runtimeContext,
      );

      await _flushMicrotasks();

      final meal = await db.mealDao.getMealById(1);
      final snapshots = await db.select(db.mealSnapshot).get();

      expect(meal?.status, 'eaten');
      expect(snapshots, isEmpty);
    });

    test('summary reminder skips meal that was already summarized', () async {
      final db = drift.DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedPlannedMeal(db);
      await db.mealDao.updateMealStatus(1, 'summarized');

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final harness = FakeRuntimeHarness(container: container);
      NotificationResponseEventHandler().handle(
        NotificationResponseEvent.mealSummaryReminderResponse(
          data: MealSummaryReminderResponseEvent.agree(mealId: 1),
        ),
        harness.runtimeContext,
      );

      await _flushMicrotasks();

      final meal = await db.mealDao.getMealById(1);
      final snapshots = await db.select(db.mealSnapshot).get();

      expect(meal?.status, 'summarized');
      expect(snapshots, isEmpty);
    });

    test(
      'manual meal start shows finished eating notification and returns to idle after confirmation',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            fakeNotifications.scheduledEvents.clear();
            final calls = <(Meal, String)>{};
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(
                  AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealStartedEatingEvent(mealId: 1),
            );
            _settle(async);

            expect(task.state, isNot(isA<MealMonitorStateIdle>()));

            _advanceMinutes(harness, async, 21);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<FinishedEatingNotificationEvent>());
            final eventTyped = event as FinishedEatingNotificationEvent;
            expect(eventTyped.mealId, 1);

            harness.dispatchEventToTask(
              task,
              FinishedEatingResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'eaten');
            calls.remove((m, s));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(fakeNotifications.scheduledEvents, hasLength(1));
            final scheduled = fakeNotifications.scheduledEvents.single;
            expect(
              scheduled.event,
              isA<MealSummaryReminderNotificationEvent>(),
            );
            final reminder =
                scheduled.event as MealSummaryReminderNotificationEvent;
            expect(reminder.mealId, 1);
            expect(
              scheduled.duration,
              FinalizeMealExecutor.summaryReminderDelay,
            );
            expect(calls, hasLength(0));
            expect(task.state, isA<MealMonitorStateIdle>());
          });
        });
      },
    );
    test(
      'manual meal start marks meal as eaten after finished eating confirmation',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(
                  AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealStartedEatingEvent(mealId: 1),
            );
            _settle(async);

            expect(task.state, isA<DetectFinishedEatingExecutor>());

            _advanceMinutes(harness, async, 10);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<FinishedEatingNotificationEvent>());
            final eventTyped = event as FinishedEatingNotificationEvent;
            expect(eventTyped.mealId, 1);

            harness.dispatchEventToTask(
              task,
              FinishedEatingResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'eaten');
            calls.remove((m, s));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<MealMonitorStateIdle>());
          });
        });
      },
    );
    test('finished eating snooze waits before showing notification again', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>{};
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(
                AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          harness.dispatchEventToTask(task, MealStartedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isA<DetectFinishedEatingExecutor>());

          _advanceMinutes(harness, async, 10);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<FinishedEatingNotificationEvent>(),
          );
          notifications.shownEvents.clear();

          harness.dispatchEventToTask(
            task,
            FinishedEatingResponseEvent.snooze(mealId: 1),
          );
          _settle(async);

          expect(notifications.shownEvents, isEmpty);

          _advanceMinutes(harness, async, 4);

          expect(notifications.shownEvents, isEmpty);

          _advanceMinutes(harness, async, 1);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<FinishedEatingNotificationEvent>(),
          );

          harness.dispatchEventToTask(
            task,
            FinishedEatingResponseEvent.agree(mealId: 1),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (meal, status) = calls.single;
          expect(meal.id, 1);
          expect(status, 'eaten');
        });
      });
    });
    test('eat now confirmation waits until meal status update completes', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final updateWaitedEating = Completer<void>();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 15)),
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(AsyncData(null)),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
                if (status == 'waited-eating') {
                  await updateWaitedEating.future;
                }
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = BolusThenWaitExecutor(recommendedMinutes: 0);
          var completed = false;
          MealMonitorStateExecutor? nextExecutor;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                completed = true;
                nextExecutor = value;
              });
          _settle(async);

          harness.dispatchEvent(
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _settle(async);

          expect(calls, hasLength(1));
          expect(calls.single.$2, 'bolused-waiting');
          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<EatNowNotificationEvent>(),
          );
          notifications.shownEvents.clear();

          harness.dispatchEvent(EatNowResponseEvent.eating(mealId: 1));
          _settle(async);

          expect(calls, hasLength(2));
          expect(calls.last.$2, 'waited-eating');
          expect(completed, isFalse);

          updateWaitedEating.complete();
          _settle(async);

          expect(completed, isTrue);
          expect(nextExecutor, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
    test('waited eating status interrupts active bolus wait', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 15)),
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                FakeNotificationsController(),
              ),
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(AsyncData(meal)),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
                    clock.now(),
                  ),
                ),
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          harness.dispatchEventToTask(task, MealBolusedWaitingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isA<BolusThenWaitExecutor>());

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _advanceMinutes(harness, async, 0);
          _settle(async);

          harness.dispatchEventToTask(task, MealWaitedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
    test(
      'missing eat now response retries before checking for the next meal',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final notifications = FakeNotificationsController();
            final meal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              overrides: [
                notificationsControllerForegroundProvider.overrideWithValue(
                  notifications,
                ),
                updateMealProvider.overrideWith((ref, args) async {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final executor = BolusThenWaitExecutor(recommendedMinutes: 0);
            var completed = false;
            MealMonitorStateExecutor? nextExecutor;

            executor
                .execute(
                  harness.runtimeContext,
                  MealMonitorContext(activeMeal: meal),
                )
                .then((value) {
                  completed = true;
                  nextExecutor = value;
                });
            _settle(async);

            harness.dispatchEvent(
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            expect(notifications.shownEvents, hasLength(1));
            expect(
              notifications.shownEvents.single,
              isA<EatNowNotificationEvent>(),
            );

            _advanceMinutes(harness, async, 10);

            expect(completed, isFalse);
            expect(notifications.shownEvents, hasLength(2));
            expect(
              notifications.shownEvents.last,
              isA<EatNowNotificationEvent>(),
            );

            _advanceMinutes(harness, async, 10);

            expect(completed, isFalse);
            expect(notifications.shownEvents, hasLength(3));
            expect(
              notifications.shownEvents.last,
              isA<EatNowNotificationEvent>(),
            );

            _advanceMinutes(harness, async, 10);

            expect(completed, isTrue);
            expect(nextExecutor, isA<NewMealCheckExecutor>());
          });
        });
      },
    );
    test('status driven bolus wait notifies after recommended wait', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 15)),
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
                    clock.now().subtract(Duration(minutes: 20)),
                  ),
                ),
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = BolusThenWaitExecutor(recommendedMinutes: null);

          unawaited(
            executor.execute(
              harness.runtimeContext,
              MealMonitorContext(activeMeal: meal),
            ),
          );
          _settle(async);

          _advanceMinutes(harness, async, 14);

          expect(notifications.shownEvents, isEmpty);

          _advanceMinutes(harness, async, 1);

          expect(notifications.shownEvents, hasLength(1));
          final event = notifications.shownEvents.single;
          expect(event, isA<EatNowNotificationEvent>());
          expect((event as EatNowNotificationEvent).mealId, 1);
          expect(event.minutes, 15);
        });
      });
    });
    test('waiting for bolus starts bolus reminder immediately', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 15)),
            carbs: 18,
          );
          const eCarbsSettings = ExtendedCarbsScheduleSettings(
            deliveryMode: ExtendedCarbsDeliveryMode.extendedCarbs,
            delayMinutes: 30,
            durationMinutes: 90,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 20),
                    clock.now(),
                    extendedCarbs: const WbtExtendedCarbsSuggestion(
                      kcal: 70,
                      wbt: 0.7,
                      grams: 7,
                      scheduleSettings: eCarbsSettings,
                    ),
                  ),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = WaitForBolusExecutor();
          var completed = false;
          MealMonitorStateExecutor? nextExecutor;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                completed = true;
                nextExecutor = value;
              });
          _settle(async);

          expect(completed, isFalse);
          expect(notifications.shownEvents, hasLength(1));
          final reminder = notifications.shownEvents.single;
          expect(reminder, isA<MealSuggestionNotificationEvent>());
          expect(
            (reminder as MealSuggestionNotificationEvent).decision,
            MealDecision.bolus,
          );
          expect(reminder.carbs, 18);
          expect(reminder.extendedCarbs, 7);
          expect(
            reminder.extendedCarbsDeliveryMode,
            eCarbsSettings.deliveryMode,
          );
          expect(reminder.extendedCarbsDelayMinutes, 30);
          expect(reminder.extendedCarbsDurationMinutes, 90);

          harness.dispatchEvent(
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _settle(async);

          expect(completed, isTrue);
          expect(nextExecutor, isA<BolusThenWaitExecutor>());
          expect(calls, hasLength(1));
          expect(calls.single.$2, 'bolused-waiting');
        });
      });
    });
    test('bolused eating waits only for finished eating confirmation', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now(),
            carbs: 22,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = DetectFinishedEatingExecutor(shouldBolus: false);
          var completed = false;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((_) {
                completed = true;
              });
          _settle(async);

          _advanceMinutes(harness, async, 5);

          expect(completed, isFalse);
          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<FinishedEatingNotificationEvent>(),
          );

          harness.dispatchEvent(FinishedEatingResponseEvent.agree(mealId: 1));
          _settle(async);

          expect(calls, hasLength(1));
          expect(calls.single.$2, 'eaten');
          expect(
            notifications.shownEvents
                .whereType<MealSuggestionNotificationEvent>(),
            isEmpty,
          );
          expect(completed, isTrue);
        });
      });
    });
    test('bolus suggestion skip after eating checks next meal', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now(),
            carbs: 10,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(AsyncData(null)),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = WaitForBolusExecutor(remindImmediately: true);
          var completed = false;
          MealMonitorStateExecutor? nextExecutor;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                completed = true;
                nextExecutor = value;
              });
          _settle(async);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<MealSuggestionNotificationEvent>(),
          );
          notifications.shownEvents.clear();

          harness.dispatchEvent(MealSuggestionResponseEvent.skip(mealId: 1));
          _settle(async);

          expect(completed, isTrue);
          expect(nextExecutor, isA<NewMealCheckExecutor>());
          expect(calls, hasLength(1));
          expect(calls.single.$1.id, 1);
          expect(calls.single.$2, 'skipped');
          expect(notifications.cancelAllCalled, isTrue);
        });
      });
    });
    test('bolus suggestion keeps reminding until calculator entry appears', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now(),
            carbs: 10,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(AsyncData(null)),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = WaitForBolusExecutor(remindImmediately: true);
          var completed = false;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((_) {
                completed = true;
              });
          _settle(async);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<MealSuggestionNotificationEvent>(),
          );
          final firstReminder =
              notifications.shownEvents.single
                  as MealSuggestionNotificationEvent;
          notifications.shownEvents.clear();

          harness.dispatchEvent(MealSuggestionResponseEvent.agree(mealId: 1));
          _settle(async);

          _advanceMinutes(harness, async, 5);

          expect(completed, isFalse);
          expect(notifications.cancelAllCalled, isTrue);
          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<MealSuggestionNotificationEvent>(),
          );
          final secondReminder =
              notifications.shownEvents.single
                  as MealSuggestionNotificationEvent;
          expect(secondReminder.key.entityId, firstReminder.key.entityId);
          final restoredSecondReminder =
              MealSuggestionNotificationEvent.fromPayload(
                Map<String, dynamic>.from(secondReminder.toJson()),
              );
          expect(
            restoredSecondReminder.key.entityId,
            secondReminder.key.entityId,
          );
          notifications.shownEvents.clear();

          harness.dispatchEvent(
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _settle(async);

          expect(completed, isTrue);
          expect(calls, hasLength(1));
          final (updatedMeal, status) = calls.single;
          expect(updatedMeal.id, 1);
          expect(status, 'eaten-bolused');
        });
      });
    });
    test('bolused status does not replace calculator bolus detection', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final meal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now(),
            carbs: 10,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              getMealAdviceProvider(meal).overrideWithValue(AsyncData(null)),
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(AsyncData(meal)),
              updateMealProvider.overrideWith((ref, args) async {}),
              mealMacronutrientsConsumedSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealMacroSummary(
                    fatGrams: 0,
                    proteinGrams: 0,
                    fiberGrams: 0,
                    carbsGrams: 10,
                    totalGrams: 10,
                  ),
                ),
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          harness.dispatchEventToTask(task, MealEatingThenBolus(mealId: 1));
          _settle(async);

          _advanceMinutes(harness, async, 5);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<FinishedEatingNotificationEvent>(),
          );
          notifications.shownEvents.clear();

          harness.dispatchEventToTask(
            task,
            FinishedEatingResponseEvent.agree(mealId: 1),
          );
          _settle(async);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<MealSuggestionNotificationEvent>(),
          );
          notifications.shownEvents.clear();

          harness.dispatchEventToTask(
            task,
            MealFinishedEatingBolusedEvent(mealId: 2),
          );
          _settle(async);

          expect(task.state, isA<WaitForBolusExecutor>());

          _advanceMinutes(harness, async, 5);

          expect(notifications.shownEvents, hasLength(1));
          expect(
            notifications.shownEvents.single,
            isA<MealSuggestionNotificationEvent>(),
          );

          harness.dispatchEventToTask(
            task,
            MealFinishedEatingBolusedEvent(mealId: 1),
          );
          _settle(async);

          expect(task.state, isA<WaitForBolusExecutor>());

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _settle(async);

          expect(task.state, isA<MealMonitorStateIdle>());
        });
      });
    });
    test(
      'meal add-on keeps reminding about missing AAPS entry and finishes as add-on',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            fakeNotifications.shownEvents.clear();
            fakeNotifications.cancelAllCalled = false;
            final calls = <(Meal, String)>{};
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                mealMacronutrientsSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      carbsGrams: 20,
                      fatGrams: 0,
                      proteinGrams: 0,
                      fiberGrams: 2,
                      totalGrams: 100,
                    ),
                  ),
                ),
                mealMacronutrientsConsumedSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      carbsGrams: 30,
                      fatGrams: 0,
                      proteinGrams: 0,
                      fiberGrams: 3,
                      totalGrams: 150,
                    ),
                  ),
                ),
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(
                  AsyncData(
                    Meal(
                      id: 1,
                      status: 'eating-extra',
                      name: 'asd',
                      plannedAt: clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                insertAdviceProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(task, MealEatingExtraEvent(mealId: 1));
            _settle(async);

            expect(task.state, isA<DetectFinishedEatingExecutor>());
            expect((task.state as DetectFinishedEatingExecutor).isAddOn, true);

            _advanceMinutes(harness, async, 10);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final reminder = fakeNotifications.lastShownEvent;
            expect(reminder, isA<MealSuggestionNotificationEvent>());
            final reminderTyped = reminder as MealSuggestionNotificationEvent;
            expect(reminderTyped.isAddOn, true);
            expect(reminderTyped.carbs, 10);
            expect(reminderTyped.title, 'Dokładka: wpisz w AAPS');

            _advanceMinutes(harness, async, 5);

            expect(fakeNotifications.cancelAllCalled, isTrue);
            expect(fakeNotifications.shownEvents, hasLength(1));
            final secondReminder = fakeNotifications.lastShownEvent;
            expect(secondReminder, isA<MealSuggestionNotificationEvent>());
            final secondReminderTyped =
                secondReminder as MealSuggestionNotificationEvent;
            expect(secondReminderTyped.isAddOn, true);
            expect(secondReminderTyped.carbs, 10);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            _advanceMinutes(harness, async, 5);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<FinishedEatingNotificationEvent>());
            final eventTyped = event as FinishedEatingNotificationEvent;
            expect(eventTyped.mealId, 1);
            expect(eventTyped.isAddOn, true);
            expect(eventTyped.title, 'Dokładka zjedzona?');

            harness.dispatchEventToTask(
              task,
              FinishedEatingResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'eaten-extra');
            calls.remove((m, s));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<MealMonitorStateIdle>());
          });
        });
      },
    );

    test(
      'shows temp target suggestion when planned meal is 26 minutes away and device status is already available',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(
                  AsyncData(
                    Meal(
                      id: 1,
                      status: 'planned',
                      name: 'asd',
                      plannedAt: clock.now().add(Duration(minutes: 26)),
                    ),
                  ),
                ),
                getMealAdviceProvider(
                  Meal(
                    id: 1,
                    status: 'planned',
                    name: 'asd',
                    plannedAt: clock.now().add(Duration(minutes: 20)),
                  ),
                ).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 0, 0),
                      clock.now(),
                    ),
                  ),
                ),
                deviceStatusValueProvider.overrideWithValue(
                  testDeviceStatus(
                    bg: 120,
                    iob: 100,
                    cob: 100,
                    date: clock.now().subtract(Duration(minutes: 2)),
                    tick: '',
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<TempTargetNotificationEvent>());
            final eventTyped = event as TempTargetNotificationEvent;
            expect(eventTyped.tempTargetString, 'Meal');

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
          });
        });
      },
    );
    test(
      'shows temp target suggestion after device status arrives for a meal planned 26 minutes ahead',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(
                  AsyncData(
                    Meal(
                      id: 1,
                      status: 'planned',
                      name: 'asd',
                      plannedAt: clock.now().add(Duration(minutes: 26)),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateExecutor>());

            final deviceStatus = testDeviceStatus(
              bg: 120,
              iob: 100,
              cob: 100,
              date: clock.now().subtract(Duration(minutes: 2)),
              tick: '',
            );
            harness.dispatchEventToTask(
              task,
              DataAvailableEvent<DeviceStatus>(deviceStatus),
            );
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateExecutor>());

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<TempTargetNotificationEvent>());
            final eventTyped = event as TempTargetNotificationEvent;
            expect(eventTyped.tempTargetString, 'Meal');

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
          });
        });
      },
    );
    test(
      'repeats temp target suggestion every 5 minutes until target event arrives',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            fakeNotifications.shownEvents.clear();
            addTearDown(fakeNotifications.shownEvents.clear);
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(
                  AsyncData(
                    Meal(
                      id: 1,
                      status: 'planned',
                      name: 'asd',
                      plannedAt: clock.now().add(Duration(minutes: 35)),
                    ),
                  ),
                ),
                deviceStatusValueProvider.overrideWithValue(
                  testDeviceStatus(
                    bg: 120,
                    iob: 100,
                    cob: 100,
                    date: clock.now().subtract(Duration(minutes: 2)),
                    tick: '',
                  ),
                ),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(fakeNotifications.shownEvents, hasLength(1));
            expect(
              fakeNotifications.shownEvents.single,
              isA<TempTargetNotificationEvent>(),
            );

            _advanceMinutes(harness, async, 5);

            expect(fakeNotifications.shownEvents, hasLength(2));

            harness.dispatchEvent(
              TreatmentAvailableEvent<TemporaryTarget>(
                _temporaryTarget(clock.now()),
              ),
            );
            _settle(async);

            _advanceMinutes(harness, async, 1);

            expect(fakeNotifications.shownEvents, hasLength(2));
            fakeNotifications.shownEvents.clear();
          });
        });
      },
    );
    test(
      'shows eat now bolus later suggestion 20 minutes before meal and moves to finished eating flow after acceptance',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final meal = Meal(
              id: 1,
              status: 'planned',
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 20)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                mealMacronutrientsSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      carbsGrams: 10,
                      fatGrams: 10,
                      proteinGrams: 10,
                      fiberGrams: 0,
                      totalGrams: 50,
                    ),
                  ),
                ),
                getNearestMealProvider.overrideWithValue(AsyncData(meal)),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                insertAdviceProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            _settle(async);
            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateExecutor>());

            for (var i = 0; i <= 4; i++) {
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: clock.now().subtract(Duration(minutes: 2)),
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
              debugPrint("Time now ${clock.now().toIso8601String()}");
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<MealSuggestionNotificationEvent>());
            final eventTyped = event as MealSuggestionNotificationEvent;
            expect(eventTyped.decision, MealDecision.eatNowBolusLater);
            expect(eventTyped.carbs, 10);
            expect(eventTyped.minutes, 0);
            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.agree(mealId: 1),
            );

            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'eating-then-bolus');
            calls.remove((m, s));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'manual bolus waiting flow marks meal as waited eating after eat now confirmation',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          final calls = <(Meal, String)>{};
          withFakeClock(async, start, () {
            final testMeal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
                getMealAdviceProvider(testMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 5, 10),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

            final deviceStatus = testDeviceStatus(
              bg: 118,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '+0',
            );
            emitDeviceStatus(harness, task, container, deviceStatus);
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealBolusedWaitingEvent(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            for (var i = 0; i < 3; i++) {
              lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: lastReadingDate,
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<EatNowNotificationEvent>());
            expect((event as EatNowNotificationEvent).mealId, 1);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'manual bolus waiting flow repeats waited eating transition after eat now confirmation',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          final calls = <(Meal, String)>{};
          withFakeClock(async, start, () {
            final testMeal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
                getMealAdviceProvider(testMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 5, 10),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

            final deviceStatus = testDeviceStatus(
              bg: 118,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '+0',
            );
            emitDeviceStatus(harness, task, container, deviceStatus);
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealBolusedWaitingEvent(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            for (var i = 0; i < 3; i++) {
              lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: lastReadingDate,
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<EatNowNotificationEvent>());
            expect((event as EatNowNotificationEvent).mealId, 1);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'shortens bolus waiting flow and shows eat now notification when glucose drops quickly',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          final calls = <(Meal, String)>{};
          withFakeClock(async, start, () {
            final testMeal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
                getMealAdviceProvider(testMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 5, 10),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                updateFinalWaitTimeProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

            final deviceStatus = testDeviceStatus(
              bg: 118,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '+0',
            );
            emitDeviceStatus(harness, task, container, deviceStatus);
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealBolusedWaitingEvent(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            for (var i = 0; i < 3; i++) {
              lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 - i * 10,
                  iob: 10,
                  cob: 10,
                  date: lastReadingDate,
                  tick: '-${i * 15}',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<EatNowNotificationEvent>());
            final eventTypedEatNow = event as EatNowNotificationEvent;
            expect(eventTypedEatNow.mealId, 1);
            expect(eventTypedEatNow.minutes, 10);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'shows bolus wait suggestion 20 minutes before meal and then transitions through bolus waiting to finished eating flow',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final meal = Meal(
              id: 1,
              status: 'planned',
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 20)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                mealMacronutrientsSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      fatGrams: 10,
                      proteinGrams: 10,
                      fiberGrams: 0,
                      carbsGrams: 10,
                      totalGrams: 50,
                    ),
                  ),
                ),
                getNearestMealProvider.overrideWithValue(AsyncData(meal)),
                getMealAdviceProvider(meal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 0, 0),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                insertAdviceProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            _settle(async);
            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateExecutor>());

            for (var i = 0; i <= 1; i++) {
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 190 + i * 4,
                  iob: 0,
                  cob: 0,
                  date: clock.now().subtract(Duration(minutes: 2)),
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
              debugPrint("Time now ${clock.now().toIso8601String()}");
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            var event = fakeNotifications.lastShownEvent;
            expect(event, isA<MealSuggestionNotificationEvent>());
            final eventTyped = event as MealSuggestionNotificationEvent;
            expect(eventTyped.decision, MealDecision.bolusWaitThenEat);
            expect(eventTyped.carbs, 10);
            expect(eventTyped.minutes, 15);
            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final bolusReminder = fakeNotifications.lastShownEvent;
            expect(bolusReminder, isA<MealSuggestionNotificationEvent>());
            expect(
              (bolusReminder as MealSuggestionNotificationEvent).decision,
              MealDecision.bolus,
            );
            final firstBolusReminderKey = bolusReminder.key;
            fakeNotifications.shownEvents.clear();
            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'waiting-for-bolus');
            calls.remove((m, s));
            expect(task.state, isA<WaitForBolusExecutor>());

            _advanceMinutes(harness, async, 5);
            expect(fakeNotifications.shownEvents, hasLength(1));
            final repeatedBolusReminder = fakeNotifications.lastShownEvent;
            expect(
              repeatedBolusReminder,
              isA<MealSuggestionNotificationEvent>(),
            );
            expect(
              (repeatedBolusReminder as MealSuggestionNotificationEvent)
                  .decision,
              MealDecision.bolus,
            );
            expect(
              repeatedBolusReminder.key.entityId,
              firstBolusReminderKey.entityId,
            );
            fakeNotifications.shownEvents.clear();

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (bolusedMeal, bolusedStatus) = calls.single;
            expect(bolusedMeal.id, 1);
            expect(bolusedStatus, 'bolused-waiting');
            calls.remove((bolusedMeal, bolusedStatus));

            var lastReadingDate = clock.now();

            for (var i = 0; i < 3; i++) {
              lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: lastReadingDate,
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            event = fakeNotifications.lastShownEvent;
            expect(event, isA<EatNowNotificationEvent>());
            final eventTypedEatNow = event as EatNowNotificationEvent;
            expect(eventTypedEatNow.mealId, 1);
            expect(eventTypedEatNow.minutes, 15);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'shows eat now notification after first bolus wait reading when glucose drops sharply',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          final calls = <(Meal, String)>{};
          withFakeClock(async, start, () {
            final testMeal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
                getMealAdviceProvider(testMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 5, 10),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                updateFinalWaitTimeProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

            final deviceStatus = testDeviceStatus(
              bg: 118,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '+0',
            );
            emitDeviceStatus(harness, task, container, deviceStatus);
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealBolusedWaitingEvent(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
            emitDeviceStatus(
              harness,
              task,
              container,
              testDeviceStatus(
                bg: 105,
                iob: 10,
                cob: 10,
                date: lastReadingDate,
                tick: '-13',
              ),
            );
            _advanceMinutes(harness, async, 5);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<EatNowNotificationEvent>());
            final eventTyped = event as EatNowNotificationEvent;
            expect(eventTyped.mealId, 1);
            expect(eventTyped.minutes, 5);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'manual meal start transitions task from idle to detect finished eating executor',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(
                  AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
                ),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealStartedEatingEvent(mealId: 1),
            );
            _settle(async);

            expect(task.state, isA<DetectFinishedEatingExecutor>());
          });
        });
      },
    );
    test(
      'manual bolus waiting flow ends with finished eating confirmation and meal marked as eaten',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          final calls = <(Meal, String)>{};
          withFakeClock(async, start, () {
            final testMeal = Meal(
              id: 1,
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 15)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                getNearestMealProvider.overrideWithValue(AsyncData(null)),
                getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
                getMealAdviceProvider(testMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(15, 5, 10),
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

            final deviceStatus = testDeviceStatus(
              bg: 118,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '+0',
            );
            emitDeviceStatus(harness, task, container, deviceStatus);
            container
                .read(deviceStatusValueProvider.notifier)
                .update(deviceStatus);
            _settle(async);

            expect(task.state, isA<MealMonitorStateIdle>());

            harness.dispatchEventToTask(
              task,
              MealBolusedWaitingEvent(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            for (var i = 0; i < 3; i++) {
              lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: lastReadingDate,
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final eatNowEvent = fakeNotifications.lastShownEvent;
            expect(eatNowEvent, isA<EatNowNotificationEvent>());
            expect((eatNowEvent as EatNowNotificationEvent).mealId, 1);

            harness.dispatchEventToTask(
              task,
              EatNowResponseEvent.eating(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (ma, sa) = calls.single;
            expect(ma.id, 1);
            expect(sa, 'waited-eating');
            calls.remove((ma, sa));

            _advanceMinutes(harness, async, 10);

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<FinishedEatingNotificationEvent>());
            final eventTypedFinished = event as FinishedEatingNotificationEvent;
            expect(eventTypedFinished.mealId, 1);

            harness.dispatchEventToTask(
              task,
              FinishedEatingResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (maa, saa) = calls.single;
            expect(maa.id, 1);
            expect(saa, 'eaten');
            calls.remove((maa, saa));

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<MealMonitorStateIdle>());
          });
        });
      },
    );
    test(
      'shows eat now bolus later suggestion and transitions to detect finished eating after acceptance',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            final calls = <(Meal, String)>{};
            final meal = Meal(
              id: 1,
              status: 'planned',
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 20)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                mealMacronutrientsSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      fatGrams: 10,
                      proteinGrams: 10,
                      fiberGrams: 0,
                      carbsGrams: 10,
                      totalGrams: 50,
                    ),
                  ),
                ),
                getNearestMealProvider.overrideWithValue(AsyncData(meal)),
                getMealAdviceProvider(meal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.eatNowBolusLater,
                      null,
                      clock.now(),
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                insertAdviceProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            _settle(async);
            task.run(harness.runtimeContext);
            _settle(async);

            expect(task.state, isA<MealMonitorStateExecutor>());

            for (var i = 0; i <= 4; i++) {
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120 + i * 4,
                  iob: 10,
                  cob: 10,
                  date: clock.now().subtract(Duration(minutes: 2)),
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
              debugPrint("Time now ${clock.now().toIso8601String()}");
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            var event = fakeNotifications.lastShownEvent;
            expect(event, isA<MealSuggestionNotificationEvent>());
            final eventTyped = event as MealSuggestionNotificationEvent;
            expect(eventTyped.decision, MealDecision.eatNowBolusLater);
            expect(eventTyped.carbs, 10);
            expect(eventTyped.minutes, 0);
            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'eating-then-bolus');
            calls.remove((m, s));

            _advanceMinutes(harness, async, 10);

            expect(fakeNotifications.shownEvents, hasLength(1));
            event = fakeNotifications.lastShownEvent;
            expect(event, isA<FinishedEatingNotificationEvent>());
            final eventTypedFinished = event as FinishedEatingNotificationEvent;
            expect(eventTypedFinished.mealId, 1);

            harness.dispatchEventToTask(
              task,
              FinishedEatingResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(fakeNotifications.shownEvents, hasLength(1));
            event = fakeNotifications.lastShownEvent;
            expect(event, isA<MealSuggestionNotificationEvent>());
            final eventTypedSuggestion =
                event as MealSuggestionNotificationEvent;
            expect(eventTypedSuggestion.decision, MealDecision.bolus);
            expect(eventTypedSuggestion.carbs, 10);
            expect(eventTypedSuggestion.minutes, 0);
            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
            );
            _settle(async);

            expect(calls, hasLength(2));
            expect(calls.map((call) => call.$1.id), everyElement(1));
            expect(
              calls.map((call) => call.$2),
              containsAll(['waiting-for-bolus', 'eaten-bolused']),
            );
            calls.clear();

            expect(fakeNotifications.shownEvents, hasLength(0));
            expect(calls, hasLength(0));
            expect(task.state, isA<MealMonitorStateIdle>());
          });
        });
      },
    );
    test(
      'accepted bolus and eat now suggestion waits for bolus before eating',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 3, 23, 12, 0);
          withFakeClock(async, start, () {
            fakeNotifications.shownEvents.clear();
            addTearDown(fakeNotifications.shownEvents.clear);
            final calls = <(Meal, String)>{};
            final meal = Meal(
              id: 1,
              status: 'planned',
              name: 'asd',
              plannedAt: clock.now().add(Duration(minutes: 20)),
            );
            final container = ProviderContainer(
              parent: parentContainer,
              overrides: [
                mealMacronutrientsSummaryProvider(1).overrideWithValue(
                  AsyncData(
                    MealMacroSummary(
                      fatGrams: 4,
                      proteinGrams: 8,
                      fiberGrams: 0,
                      carbsGrams: 20,
                      totalGrams: 80,
                    ),
                  ),
                ),
                getNearestMealProvider.overrideWithValue(AsyncData(meal)),
                updateMealProvider.overrideWith((ref, args) async {
                  final (meal, status) = args;
                  calls.add((meal, status));
                }),
                insertAdviceProvider.overrideWith((ref, args) {}),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();

            task.run(harness.runtimeContext);
            _settle(async);

            for (var i = 0; i <= 4; i++) {
              emitDeviceStatus(
                harness,
                task,
                container,
                testDeviceStatus(
                  bg: 120,
                  iob: 0,
                  cob: 0,
                  date: clock.now().subtract(Duration(minutes: 2)),
                  tick: '',
                ),
              );
              _advanceMinutes(harness, async, 5);
            }

            expect(fakeNotifications.shownEvents, hasLength(1));
            final event = fakeNotifications.lastShownEvent;
            expect(event, isA<MealSuggestionNotificationEvent>());
            final eventTyped = event as MealSuggestionNotificationEvent;
            expect(eventTyped.decision, MealDecision.bolusAndEatNow);
            expect(eventTyped.carbs, 20);

            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.agree(mealId: 1),
            );
            _settle(async);

            expect(calls, hasLength(1));
            final (m, s) = calls.single;
            expect(m.id, 1);
            expect(s, 'waiting-for-bolus');
            expect(task.state, isA<WaitForBolusExecutor>());

            expect(fakeNotifications.shownEvents, hasLength(1));
            final bolusReminder = fakeNotifications.lastShownEvent;
            expect(bolusReminder, isA<MealSuggestionNotificationEvent>());
            expect(
              (bolusReminder as MealSuggestionNotificationEvent).decision,
              MealDecision.bolus,
            );

            harness.dispatchEventToTask(
              task,
              MealSuggestionResponseEvent.skip(mealId: 1),
            );
            _settle(async);

            expect(calls.map((call) => call.$2), contains('skipped'));
          });
        });
      },
    );
    test('waiting for bolus uses recent cached calculator response', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            status: 'waiting-for-bolus',
            name: 'asd',
            plannedAt: clock.now(),
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              latestBolusWizardProvider.overrideWithValue(
                testBolusWizard(createdAt: clock.now()),
              ),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusAndEatNow,
                    null,
                    clock.now(),
                  ),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = WaitForBolusExecutor();
          var completed = false;
          MealMonitorStateExecutor? nextExecutor;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                completed = true;
                nextExecutor = value;
              });
          _settle(async);

          expect(completed, isTrue);
          expect(calls, hasLength(1));
          expect(calls.single.$2, 'bolused-eating');
          expect(nextExecutor, isA<DetectFinishedEatingExecutor>());
          expect(notifications.shownEvents, isEmpty);
        });
      });
    });
    test('waiting for bolus accepts cached bolus after meal status update', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final notifications = FakeNotificationsController();
          final calls = <(Meal, String)>[];
          final meal = Meal(
            id: 1,
            status: 'waiting-for-bolus',
            name: 'asd',
            plannedAt: clock.now(),
            updatedAt: start,
          );
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                notifications,
              ),
              latestBolusWizardProvider.overrideWithValue(
                testBolusWizard(createdAt: start.add(Duration(minutes: 1))),
              ),
              getMealByIdProvider(1).overrideWithValue(AsyncData(meal)),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusAndEatNow,
                    null,
                    clock.now(),
                  ),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final executor = WaitForBolusExecutor(
            waitingSince: start.add(Duration(minutes: 2)),
          );
          var completed = false;
          MealMonitorStateExecutor? nextExecutor;

          executor
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                completed = true;
                nextExecutor = value;
              });
          _settle(async);

          expect(completed, isTrue);
          expect(calls, hasLength(1));
          expect(calls.single.$2, 'bolused-eating');
          expect(nextExecutor, isA<DetectFinishedEatingExecutor>());
          expect(notifications.shownEvents, isEmpty);
        });
      });
    });
    test('user manualy eat then bolus', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(
                AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
              ),
              mealMacronutrientsSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealMacroSummary(
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 0,
                    carbsGrams: 10,
                    totalGrams: 50,
                  ),
                ),
              ),
              mealMacronutrientsConsumedSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealMacroSummary(
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 0,
                    carbsGrams: 52,
                    totalGrams: 50,
                  ),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MealMonitorStateIdle>());

          harness.dispatchEventToTask(task, MealEatingThenBolus(mealId: 1));
          _settle(async);

          expect(task.state, isA<DetectFinishedEatingExecutor>());

          _advanceMinutes(harness, async, 10);

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<FinishedEatingNotificationEvent>());
          final eventTypedFinished = event as FinishedEatingNotificationEvent;
          expect(eventTypedFinished.mealId, 1);

          harness.dispatchEventToTask(
            task,
            FinishedEatingResponseEvent.agree(mealId: 1),
          );
          _settle(async);
          _settle(async);

          expect(calls, hasLength(1));
          final (maa, saa) = calls.single;
          expect(maa.id, 1);
          expect(saa, 'waiting-for-bolus');
          expect(task.state, isA<WaitForBolusExecutor>());
        });
      });
    });
    test('user manualy bolus then eat', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(
                AsyncData(Meal(id: 1, name: 'asd', plannedAt: clock.now())),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MealMonitorStateIdle>());

          harness.dispatchEventToTask(task, MealBolusedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isA<DetectFinishedEatingExecutor>());

          expect(calls, isEmpty);

          _advanceMinutes(harness, async, 10);

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<FinishedEatingNotificationEvent>());
          final eventTypedFinished = event as FinishedEatingNotificationEvent;
          expect(eventTypedFinished.mealId, 1);

          harness.dispatchEventToTask(
            task,
            FinishedEatingResponseEvent.agree(mealId: 1),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (maa, saa) = calls.single;
          expect(maa.id, 1);
          expect(saa, 'eaten');
          calls.remove((maa, saa));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<MealMonitorStateIdle>());
        });
      });
    });

    test('wait for bolus 5 min big drop, user manually selects from ui', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        final calls = <(Meal, String)>{};
        withFakeClock(async, start, () {
          final testMeal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 15)),
          );
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              getNearestMealProvider.overrideWithValue(AsyncData(null)),
              getMealByIdProvider(1).overrideWithValue(AsyncData(testMeal)),
              getMealAdviceProvider(testMeal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
                    clock.now(),
                  ),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
              updateFinalWaitTimeProvider.overrideWith((ref, args) {}),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          task.run(harness.runtimeContext);
          _settle(async);

          var lastReadingDate = clock.now().subtract(Duration(minutes: 2));

          final deviceStatus = testDeviceStatus(
            bg: 118,
            iob: 10,
            cob: 10,
            date: lastReadingDate,
            tick: '+0',
          );
          emitDeviceStatus(harness, task, container, deviceStatus);
          container
              .read(deviceStatusValueProvider.notifier)
              .update(deviceStatus);
          _settle(async);

          expect(task.state, isA<MealMonitorStateIdle>());

          harness.dispatchEventToTask(task, MealBolusedWaitingEvent(mealId: 1));
          _settle(async);

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<BolusWizard>(testBolusWizard()),
          );
          _settle(async);

          lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
          emitDeviceStatus(
            harness,
            task,
            container,
            testDeviceStatus(
              bg: 105,
              iob: 10,
              cob: 10,
              date: lastReadingDate,
              tick: '-13',
            ),
          );
          _advanceMinutes(harness, async, 5);

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTyped = event as EatNowNotificationEvent;
          expect(eventTyped.mealId, 1);
          expect(eventTyped.minutes, 5);

          harness.dispatchEventToTask(
            task,
            EatNowResponseEvent.eating(mealId: 1),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (ma, sa) = calls.single;
          expect(ma.id, 1);
          expect(sa, 'waited-eating');
          calls.remove((ma, sa));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
    test('Meal advisor should interrupt when eating earlier', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
          final meal = Meal(
            id: 1,
            status: 'planned',
            name: 'asd',
            plannedAt: clock.now().add(Duration(minutes: 20)),
          );
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              mealMacronutrientsSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealMacroSummary(
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                    carbsGrams: 10,
                    totalGrams: 50,
                  ),
                ),
              ),
              mealMacronutrientsConsumedSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealMacroSummary(
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                    carbsGrams: 10,
                    totalGrams: 50,
                  ),
                ),
              ),
              getNearestMealProvider.overrideWithValue(AsyncData(meal)),
              getMealByIdProvider(1).overrideWithValue(
                AsyncData(meal.copyWith(status: 'eating-then-bolus')),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                final (meal, status) = args;
                calls.add((meal, status));
              }),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();

          _settle(async);
          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MonitorUntilMeal>());

          emitDeviceStatus(
            harness,
            task,
            container,
            testDeviceStatus(
              bg: 124,
              iob: 10,
              cob: 10,
              date: clock.now().subtract(Duration(minutes: 2)),
              tick: '+4',
            ),
          );
          _settle(async);

          harness.dispatchEventToTask(
            task,
            MealStatusChangedEvent.eatingThenBolus(mealId: 1),
          );
          _settle(async);

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
  });
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TemporaryTarget _temporaryTarget(DateTime createdAt) {
  return TemporaryTarget(
    nightscoutId: 'target-1',
    createdAt: createdAt,
    durationInMiliseconds: const Duration(hours: 1).inMilliseconds,
    duration: 60,
    targetBottom: 150,
    targetTop: 150,
  );
}

Future<void> _seedPlannedMeal(drift.DatabaseImpl db) async {
  await db.customInsert('''
    INSERT INTO ingredient (
      id,
      name,
      carbs_per_100g,
      fat_per_100g,
      fiber_per_100g,
      protein_per_100g,
      nutrition_confidence
    ) VALUES (1, 'Ryż', 20, 0, 5, 2, 1)
  ''');

  await db.customInsert('''
    INSERT INTO meal (
      id,
      name,
      planned_at,
      status
    ) VALUES (1, 'Obiad', 1774270800000, 'eaten')
  ''');

  await db.customInsert('''
    INSERT INTO meal_ingredients (
      id,
      meal_id,
      ingredient_id,
      portion_id,
      amount,
      quantity_confidence
    ) VALUES (1, 1, 1, NULL, 100, 1)
  ''');
}
