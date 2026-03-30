import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/meal_suggestion_response_event.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
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
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/bolus_then_wait_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
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
    test('manual meal start shows finished eating notification and returns to idle after confirmation', () {
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

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(task.state, isA<MealMonitorStateIdle>());
        });
      });
    });
    test('manual meal start marks meal as eaten after finished eating confirmation', () {
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

          expect(task.state, isA<DetectFinishedEatingExecutor>());

          async.elapse(const Duration(minutes: 10));

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
    });
    test('shows temp target suggestion when planned meal is 26 minutes away and device status is already available', () {
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
    test('shows eat now bolus later suggestion 20 minutes before meal and moves to finished eating flow after acceptance', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
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
    test('manual bolus waiting flow marks meal as waited eating after eat now confirmation', () {
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
                    clock.now()
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
    test('manual bolus waiting flow repeats waited eating transition after eat now confirmation', () {
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
                    clock.now()
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
    test('shortens bolus waiting flow and shows eat now notification when glucose drops quickly', () {
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
                    clock.now()
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

          for (var i = 0; i < 3; i++) {
            lastReadingDate = lastReadingDate.add(Duration(minutes: 5));
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 120 - i * 10,
                iob: 10,
                cob: 10,
                id: 0,
                date: lastReadingDate,
                tick: '-${i*15}',
              ),
            );
            async.elapse(Duration(minutes: 5));
          }

          expect(fakeNotifications.shownEvents, hasLength(1));
          final event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTypedEatNow = event as EatNowNotificationEvent;
          expect(eventTypedEatNow.mealId, 1);
          expect(eventTypedEatNow.minutes, 0);

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
    test('shows bolus wait suggestion 20 minutes before meal and then transitions through bolus waiting to finished eating flow', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
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

          for (var i = 0; i <= 1; i++) {
            emitDeviceStatus(
              harness,
              task,
              container,
              DeviceStatus(
                bg: 190 + i * 4,
                iob: 0,
                cob: 0,
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
          expect(eventTyped.decision, MealDecision.bolusWaitThenEat);
          expect(eventTyped.carbs, 10);
          expect(eventTyped.minutes, 15);
          harness.dispatchEventToTask(
            task,
            MealSuggestionResponseEvent.agree(mealId: 1),
          );
          _settle(async);

          expect(fakeNotifications.shownEvents, hasLength(0));
          expect(calls, hasLength(0));
          expect(task.state, isA<BolusThenWaitExecutor>());

          harness.dispatchEventToTask(
            task,
            TreatmentAvailableEvent<Meal>(Meal(id: 0, name: '')),
          );
          _settle(async);

          expect(calls, hasLength(1));
          final (m, s) = calls.single;
          expect(m.id, 1);
          expect(s, 'bolused-waiting');
          calls.remove((m, s));

          var lastReadingDate = clock.now();

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
          event = fakeNotifications.lastShownEvent;
          expect(event, isA<EatNowNotificationEvent>());
          final eventTypedEatNow = event as EatNowNotificationEvent;
          expect(eventTypedEatNow.mealId, 1);
          expect(eventTypedEatNow.minutes, 0);

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
    test('shows eat now notification after first bolus wait reading when glucose drops sharply', () {
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
                    clock.now()
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
    test('manual meal start transitions task from idle to detect finished eating executor', () {
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

          expect(task.state, isA<DetectFinishedEatingExecutor>());
        });
      });
    });
    test('manual bolus waiting flow ends with finished eating confirmation and meal marked as eaten', () {
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
                    clock.now()
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
    test('shows eat now bolus later suggestion and transitions to detect finished eating after acceptance', () {
      fakeAsync((async) {
        final start = DateTime(2026, 3, 23, 12, 0);
        withFakeClock(async, start, () {
          final calls = <(Meal, String)>{};
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
          expect(task.state, isA<MealMonitorStateIdle>());
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
          expect(task.state, isA<MealMonitorStateIdle>());
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
                    clock.now()
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
                  MealMacroSummary(
                    fatGrams: 10,
                    proteinGrams: 10,
                    fiberGrams: 10,
                    carbsGrams: 10,
                    totalGrams: 50,
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
