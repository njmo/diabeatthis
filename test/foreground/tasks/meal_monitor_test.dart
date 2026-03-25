import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_summary.dart';
import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/finished_eating_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/foreground/event/internal/data_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/meal_monitor_state_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void withFakeClock(FakeAsync async, DateTime start, void Function() body) {
  withClock(Clock(() => start.add(async.elapsed)), body);
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

class UpdateMealSpy {
  final calls = <(Meal, String)>[];

  Future<void> call(Meal meal, String status) async {
    calls.add((meal, status));
  }
}

void main() {
  LogRuntimeConfig.configure(isUnitTest: true, enableBuffer: false);

  group("MealMonitorTask tests", () {
    test('task reacts to emitted events', () {
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

          harness.dispatchEventToTask(task, MealStartedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isNot(isA<MealMonitorStateIdle>()));

          async.elapse(const Duration(minutes: 21));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(task.state, isA<MealMonitorStateIdle>());
        });
      });
    });
    test('task reacts to emitted as', () {
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

          harness.dispatchEventToTask(task, MealStartedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isNot(isA<MealMonitorStateIdle>()));

          final treatmentsMeal = Meal(
            id: 1,
            name: 'asd',
            plannedAt: clock.now(),
          );

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<Meal>(treatmentsMeal),
          );

          _settle(async);
          expect(calls, hasLength(1));

          final (meal, status) = calls.single;
          expect(meal.id, 1);
          expect(status, 'bolused-eating');
          calls.remove((meal, status));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
    test('Temp target suggested when more than 26 minutes and bg > 120', () {
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
              deviceStatusValueProvider.overrideWithValue(
                DeviceStatus(
                  bg: 120,
                  iob: 100,
                  cob: 100,
                  id: 0,
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
    });
    test(
      'Temp target suggested when more than 26 minutes and bg > 120 waiting for device status',
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

            final deviceStatus = DeviceStatus(
              bg: 120,
              iob: 100,
              cob: 100,
              id: 0,
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
    test('Meal advisor only 20 minutes left', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              mealMacronutrientsSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealSummary(
                    carbsG: 10,
                    proteinKcal: 10,
                    fatKcal: 10,
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                  ),
                ),
              ),
              getNearestMealProvider.overrideWithValue(
                AsyncData(
                  Meal(
                    id: 1,
                    status: 'planned',
                    name: 'asd',
                    plannedAt: clock.now().add(Duration(minutes: 20)),
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

          _settle(async);
          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MealMonitorStateExecutor>());

          for (var i = 0; i <= 4; i++) {
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 120 + i * 4,
                iob: 10,
                cob: 10,
                id: 0,
                date: clock.now().subtract(Duration(minutes: 2)),
                tick: '',
              ),
            );
            async.elapse(Duration(minutes: 5));
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
    });
    test('wait for bolus 15 min', () {
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
                  MealAdvice(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
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

          final deviceStatus = DeviceStatus(
            bg: 118,
            iob: 10,
            cob: 10,
            id: 0,
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
            TreatmentAvailableEvent<Meal>(testMeal),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (m, s) = calls.single;
          expect(m.id, 1);
          expect(s, 'bolused-waiting');
          calls.remove((m, s));

          for (var i = 0; i < 3; i++) {
            lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 120 + i * 4,
                iob: 10,
                cob: 10,
                id: 0,
                date: lastReadingDate,
                tick: '',
              ),
            );
            async.elapse(Duration(minutes: 5));
          }

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTyped = event as EatNowNotificationEvent;
          expect(eventTyped.mealId, 1);
          expect(eventTyped.minutes, 0);

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
    test('wait for bolus 5 min big drop', () {
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
                  MealAdvice(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
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

          final deviceStatus = DeviceStatus(
            bg: 118,
            iob: 10,
            cob: 10,
            id: 0,
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
            TreatmentAvailableEvent<Meal>(testMeal),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (m, s) = calls.single;
          expect(m.id, 1);
          expect(s, 'bolused-waiting');
          calls.remove((m, s));

          lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
          emitDeviceStatus(
            harness,
            task,
            container,
            DeviceStatus(
              bg: 105,
              iob: 10,
              cob: 10,
              id: 0,
              date: lastReadingDate,
              tick: '-13',
            ),
          );
          async.elapse(Duration(minutes: 5));

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTyped = event as EatNowNotificationEvent;
          expect(eventTyped.mealId, 1);
          expect(eventTyped.minutes, 0);

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
    test('task reacts to emitted events', () {
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

          harness.dispatchEventToTask(task, MealStartedEatingEvent(mealId: 1));
          _settle(async);

          expect(task.state, isNot(isA<MealMonitorStateIdle>()));

          async.elapse(const Duration(minutes: 21));

          expect(task.state, isA<MealMonitorStateIdle>());
        });
      });
    });
    test('wait for bolus 15 min then wait for finish', () {
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
                  MealAdvice(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
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

          final deviceStatus = DeviceStatus(
            bg: 118,
            iob: 10,
            cob: 10,
            id: 0,
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
            TreatmentAvailableEvent<Meal>(testMeal),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (m, s) = calls.single;
          expect(m.id, 1);
          expect(s, 'bolused-waiting');
          calls.remove((m, s));

          for (var i = 0; i < 3; i++) {
            lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 120 + i * 4,
                iob: 10,
                cob: 10,
                id: 0,
                date: lastReadingDate,
                tick: '',
              ),
            );
            async.elapse(Duration(minutes: 5));
          }

          expect(fakeNotifications.shownEvents, hasLength(1));
          var event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTyped = event as EatNowNotificationEvent;
          expect(eventTyped.mealId, 1);
          expect(eventTyped.minutes, 0);

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

          async.elapse(Duration(minutes: 10));

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

          expect(calls, hasLength(1));
          final (maa, saa) = calls.single;
          expect(maa.id, 1);
          expect(saa, 'eaten');
          calls.remove((maa, saa));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<FinalizeMealExecutor>());
        });
      });
    });
    test('Meal advisor eat then bolus', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              mealMacronutrientsSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealSummary(
                    carbsG: 10,
                    proteinKcal: 10,
                    fatKcal: 10,
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                  ),
                ),
              ),
              getNearestMealProvider.overrideWithValue(
                AsyncData(
                  Meal(
                    id: 1,
                    status: 'planned',
                    name: 'asd',
                    plannedAt: clock.now().add(Duration(minutes: 20)),
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

          _settle(async);
          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MealMonitorStateExecutor>());

          for (var i = 0; i <= 4; i++) {
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 120 + i * 4,
                iob: 10,
                cob: 10,
                id: 0,
                date: clock.now().subtract(Duration(minutes: 2)),
                tick: '',
              ),
            );
            async.elapse(Duration(minutes: 5));
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

          async.elapse(Duration(minutes: 10));

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
          final eventTypedSuggestion = event as MealSuggestionNotificationEvent;
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
            TreatmentAvailableEvent<Meal>(Meal(id: 0, name: '')),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (maa, saa) = calls.single;
          expect(maa.id, 1);
          expect(saa, 'bolused-eaten');
          calls.remove((maa, saa));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<FinalizeMealExecutor>());
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
                  MealSummary(
                    carbsG: 10,
                    proteinKcal: 10,
                    fatKcal: 10,
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
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

          async.elapse(Duration(minutes: 10));

          expect(fakeNotifications.shownEvents, hasLength(1));
          var event = fakeNotifications.lastShownEvent;
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
          final eventTypedSuggestion = event as MealSuggestionNotificationEvent;
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
            TreatmentAvailableEvent<Meal>(Meal(id: 0, name: '')),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (maa, saa) = calls.single;
          expect(maa.id, 1);
          expect(saa, 'bolused-eaten');
          calls.remove((maa, saa));

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<FinalizeMealExecutor>());
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

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<Meal>(Meal(id: 0, name: '')),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (ma, sa) = calls.single;
          expect(ma.id, 1);
          expect(sa, 'bolused-eating');
          calls.remove((ma, sa));

          async.elapse(Duration(minutes: 10));

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
          expect(task.state, isA<FinalizeMealExecutor>());
        });
      });
    });

    test('wait for bolus 5 min big drop', () {
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
                  MealAdvice(
                    MealDecision.bolusWaitThenEat,
                    WaitSuggestion(15, 5, 10),
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

          final deviceStatus = DeviceStatus(
            bg: 118,
            iob: 10,
            cob: 10,
            id: 0,
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
            TreatmentAvailableEvent<Meal>(testMeal),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (m, s) = calls.single;
          expect(m.id, 1);
          expect(s, 'bolused-waiting');
          calls.remove((m, s));

          lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
          emitDeviceStatus(
            harness,
            task,
            container,
            DeviceStatus(
              bg: 105,
              iob: 10,
              cob: 10,
              id: 0,
              date: lastReadingDate,
              tick: '-13',
            ),
          );
          async.elapse(Duration(minutes: 5));

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTyped = event as EatNowNotificationEvent;
          expect(eventTyped.mealId, 1);
          expect(eventTyped.minutes, 0);

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
          final container = ProviderContainer(
            parent: parentContainer,
            overrides: [
              mealMacronutrientsSummaryProvider(1).overrideWithValue(
                AsyncData(
                  MealSummary(
                    carbsG: 10,
                    proteinKcal: 10,
                    fatKcal: 10,
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                  ),
                ),
              ),
              getNearestMealProvider.overrideWithValue(
                AsyncData(
                  Meal(
                    id: 1,
                    status: 'planned',
                    name: 'asd',
                    plannedAt: clock.now().add(Duration(minutes: 20)),
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

          _settle(async);
          task.run(harness.runtimeContext);
          _settle(async);

          expect(task.state, isA<MonitorUntilMeal>());

          emitDeviceStatus(
            harness,
            task,
            container,
            DeviceStatus(
              bg: 124,
              iob: 10,
              cob: 10,
              id: 0,
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
