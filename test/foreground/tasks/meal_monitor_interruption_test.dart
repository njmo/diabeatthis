import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/eat_now_response_event.dart';
import 'package:diabeatthis/common/events/data/notification/finished_eating_response_event.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/eat_now_event_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_summary_reminder_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/bolus_then_wait_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';
import '../utils/pending_notifications_controller.dart';

void main() {
  for (final terminal in ['interrupted', 'summarized']) {
    test('parses the $terminal terminal event', () {
      final event = MealStatusChangedEvent.fromJson({
        'kind': terminal,
        'mealId': 7,
      });
      expect(event.mealId, 7);
      expect(
        event,
        terminal == 'interrupted'
            ? isA<MealInterruptedEvent>()
            : isA<MealSummarizedEvent>(),
      );
    });

    for (final status in [
      'planned',
      'waiting-for-bolus',
      'bolused-waiting',
      'eating',
      'eating-then-bolus',
      'bolused-eating',
      'waited-eating',
      'eating-extra',
    ]) {
      test(
        '$terminal stops $status without changing meal data or other notifications',
        () {
          fakeAsync((async) {
            final start = DateTime(2026, 11, 1, 12);
            withClock(Clock(() => start.add(async.elapsed)), () {
              final meal = Meal(
                id: 1,
                name: 'Lunch',
                status: status,
                plannedAt: start.add(const Duration(hours: 2)),
                carbs: 20,
              );
              final notifications = PendingNotificationsController();
              final changes = <String>[];
              var nearestReads = 0;
              final container = ProviderContainer(
                overrides: [
                  notificationsControllerForegroundProvider.overrideWithValue(
                    notifications,
                  ),
                  getNearestMealProvider.overrideWith(
                    (ref) async => nearestReads++ == 0 ? meal : null,
                  ),
                  getMealAdviceProvider(meal).overrideWithValue(
                    AsyncData(
                      MealAdvice.full(
                        MealDecision.bolusWaitThenEat,
                        WaitSuggestion(15, 5, 10),
                        start,
                      ),
                    ),
                  ),
                  mealMacronutrientsConsumedSummaryProvider(
                    1,
                  ).overrideWithValue(const AsyncData(null)),
                  updateMealProvider.overrideWith((ref, args) async {
                    changes.add(args.$2);
                  }),
                ],
              );
              final harness = FakeRuntimeHarness(container: container);
              final ownOffer = TempTargetNotificationEvent.meal(entityId: 1);
              const ownInstruction = AapsBolusSuggestionNotificationEvent(
                mealId: 1,
                carbs: 20,
              );
              final nextOffer = TempTargetNotificationEvent.meal(entityId: 2);
              final otherReminder = EatNowNotificationEvent(
                mealId: 2,
                minutes: 15,
              );
              unawaited(notifications.show(ownOffer));
              unawaited(notifications.show(ownInstruction));
              unawaited(notifications.show(nextOffer));
              unawaited(notifications.show(otherReminder));
              final task = MealMonitorTask();
              unawaited(
                task.run(harness.runtimeContext).catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                }),
              );
              async.flushMicrotasks();

              final foreign = terminal == 'interrupted'
                  ? const MealInterruptedEvent(mealId: 2)
                  : const MealSummarizedEvent(mealId: 2);
              expect(task.shouldInterrupt(foreign), isFalse);
              final event = terminal == 'interrupted'
                  ? const MealInterruptedEvent(mealId: 1)
                  : const MealSummarizedEvent(mealId: 1);
              harness.dispatchEventToTask(task, event);
              async.flushMicrotasks();

              expect(task.state, isA<MealMonitorStateIdle>());
              expect(changes, isEmpty);
              expect(notifications.cancelAllCalled, isFalse);
              expect(notifications.contains(ownOffer), isFalse);
              expect(
                notifications.contains(ownInstruction),
                terminal == 'summarized',
              );
              expect(notifications.contains(nextOffer), isTrue);
              expect(notifications.contains(otherReminder), isTrue);
              expect(notifications.scheduledEvents, isEmpty);
              final shown = notifications.shownEvents.length;
              harness.dispatchEventToTask(
                task,
                const EatNowResponseEvent.eating(mealId: 1),
              );
              harness.dispatchEventToTask(
                task,
                const FinishedEatingResponseEvent.agree(mealId: 1),
              );
              async.elapse(const Duration(hours: 1));
              harness.dispatchTick(clock.now());
              async.flushMicrotasks();
              expect(changes, isEmpty);
              expect(notifications.shownEvents, hasLength(shown));
              expect(
                harness.emittedEvents
                    .whereType<MealMonitoringStatusChanged>()
                    .last
                    .status
                    .phase,
                MealMonitoringPhase.idle,
              );
              harness.cancel();
              async.flushMicrotasks();
              container.dispose();
            });
          });
        },
      );
    }
  }

  test(
    'interruption refreshes the next planned meal without reactivating the old meal',
    () {
      fakeAsync((async) {
        final start = DateTime(2026, 11, 1, 12);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final current = Meal(
            id: 1,
            name: 'Lunch',
            status: 'eating',
            plannedAt: start.add(const Duration(hours: 1)),
          );
          final next = Meal(
            id: 2,
            name: 'Dinner',
            status: 'planned',
            plannedAt: start.add(const Duration(hours: 4)),
          );
          var reads = 0;
          final container = ProviderContainer(
            overrides: [
              notificationsControllerForegroundProvider.overrideWithValue(
                PendingNotificationsController(),
              ),
              getNearestMealProvider.overrideWith(
                (ref) async => reads++ == 0 ? current : next,
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          final task = MealMonitorTask();
          unawaited(
            task.run(harness.runtimeContext).catchError((Object error) {
              if (error is! TaskCancelledException) throw error;
            }),
          );
          async.flushMicrotasks();
          harness.dispatchEventToTask(
            task,
            const MealInterruptedEvent(mealId: 1),
          );
          async.flushMicrotasks();
          expect(task.state, isA<MonitorUntilMeal>());
          expect(
            harness.emittedEvents
                .whereType<MealMonitoringStatusChanged>()
                .last
                .status
                .mealId,
            2,
          );
          expect(
            task.shouldInterrupt(const MealInterruptedEvent(mealId: 1)),
            isFalse,
          );
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    },
  );

  test('interruption during delayed advice prevents a late bolus reminder', () {
    fakeAsync((async) {
      final start = DateTime(2026, 11, 1, 12);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final meal = Meal(
          id: 1,
          name: 'Lunch',
          status: 'waiting-for-bolus',
          plannedAt: start.add(const Duration(hours: 2)),
          carbs: 20,
        );
        final advice = Completer<MealAdvice?>();
        final notifications = PendingNotificationsController();
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
            getNearestMealProvider.overrideWith(
              (ref) async => reads++ == 0 ? meal : null,
            ),
            getMealAdviceProvider(meal).overrideWith((ref) => advice.future),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final task = MealMonitorTask();
        unawaited(
          task.run(harness.runtimeContext).catchError((Object error) {
            if (error is! TaskCancelledException) throw error;
          }),
        );
        async.flushMicrotasks();
        harness.dispatchEventToTask(
          task,
          const MealInterruptedEvent(mealId: 1),
        );
        advice.complete(
          MealAdvice.full(MealDecision.bolusAndEatNow, null, start),
        );
        async.flushMicrotasks();
        expect(task.state, isA<MealMonitorStateIdle>());
        expect(notifications.shownEvents, isEmpty);
        expect(notifications.scheduledEvents, isEmpty);
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    });
  });

  test('an explicit add-on can reopen a summarized meal', () {
    fakeAsync((async) {
      final start = DateTime(2026, 11, 1, 12);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final meal = Meal(
          id: 1,
          name: 'Lunch',
          status: 'eating',
          plannedAt: start.add(const Duration(hours: 2)),
        );
        final notifications = PendingNotificationsController();
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
            getNearestMealProvider.overrideWith(
              (ref) async => reads++ == 0 ? meal : null,
            ),
            getMealByIdProvider(1).overrideWith(
              (ref) async => meal.copyWith(status: 'eating-extra'),
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final task = MealMonitorTask();
        unawaited(
          task.run(harness.runtimeContext).catchError((Object error) {
            if (error is! TaskCancelledException) throw error;
          }),
        );
        async.flushMicrotasks();
        harness.dispatchEventToTask(task, const MealSummarizedEvent(mealId: 1));
        async.flushMicrotasks();
        expect(task.state, isA<MealMonitorStateIdle>());
        harness.dispatchEventToTask(
          task,
          const MealEatingExtraEvent(mealId: 1),
        );
        async.flushMicrotasks();
        expect(task.state, isA<DetectFinishedEatingExecutor>());
        expect(
          harness.emittedEvents
              .whereType<MealMonitoringStatusChanged>()
              .last
              .status
              .mealId,
          1,
        );
        expect(notifications.scheduledEvents, isEmpty);
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    });
  });

  test('a meal interrupted during the nearest-meal read is never started', () {
    fakeAsync((async) {
      final start = DateTime(2026, 11, 1, 12);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final result = Completer<Meal?>();
        final notifications = PendingNotificationsController();
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
            getNearestMealProvider.overrideWith(
              (ref) => reads++ == 0 ? result.future : Future.value(null),
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final task = MealMonitorTask();
        unawaited(
          task.run(harness.runtimeContext).catchError((Object error) {
            if (error is! TaskCancelledException) throw error;
          }),
        );
        async.flushMicrotasks();
        harness.dispatchEventToTask(
          task,
          const MealInterruptedEvent(mealId: 1),
        );
        result.complete(
          Meal(
            id: 1,
            name: 'Stopped meal',
            status: 'planned',
            plannedAt: start.add(const Duration(hours: 2)),
          ),
        );
        async.flushMicrotasks();
        expect(task.state, isA<MealMonitorStateIdle>());
        expect(notifications.shownEvents, isEmpty);
        expect(
          harness.emittedEvents.whereType<MealMonitoringStatusChanged>().where(
            (event) => event.status.mealId == 1,
          ),
          isEmpty,
        );
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    });
  });

  test('summary saved during reminder scheduling cancels that reminder', () {
    fakeAsync((async) {
      final start = DateTime(2026, 11, 1, 12);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final meal = Meal(
          id: 1,
          name: 'Lunch',
          status: 'eaten',
          plannedAt: start.add(const Duration(hours: 2)),
        );
        final scheduling = Completer<void>();
        final notifications = PendingNotificationsController()
          ..enqueueScheduleFuture(scheduling.future);
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            notificationsControllerForegroundProvider.overrideWithValue(
              notifications,
            ),
            getNearestMealProvider.overrideWith(
              (ref) async => reads++ == 0 ? meal : null,
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        final task = MealMonitorTask();
        unawaited(
          task.run(harness.runtimeContext).catchError((Object error) {
            if (error is! TaskCancelledException) throw error;
          }),
        );
        async.flushMicrotasks();
        expect(notifications.scheduledEvents, hasLength(1));
        harness.dispatchEventToTask(task, const MealSummarizedEvent(mealId: 1));
        scheduling.complete();
        async.flushMicrotasks();
        final summaryId = const HashNotificationIdFactory().create(
          MealSummaryReminderNotificationEvent(mealId: 1).key,
        );
        expect(
          notifications.cancelledIds.where((id) => id == summaryId),
          hasLength(2),
        );
        expect(task.state, isA<MealMonitorStateIdle>());
        expect(notifications.cancelAllCalled, isFalse);
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    });
  });

  for (final awaitingFood in [true, false]) {
    test(
      'ignores another meal ${awaitingFood ? 'eat now' : 'finished eating'} response',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 11, 1, 12);
          withClock(Clock(() => start.add(async.elapsed)), () {
            final meal = Meal(
              id: 2,
              name: 'Current meal',
              plannedAt: start,
              status: awaitingFood ? 'bolused-waiting' : 'eating',
            );
            final changes = <String>[];
            final container = ProviderContainer(
              overrides: [
                notificationsControllerForegroundProvider.overrideWithValue(
                  PendingNotificationsController(),
                ),
                getMealAdviceProvider(meal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(
                      MealDecision.bolusWaitThenEat,
                      WaitSuggestion(0, 0, 0),
                      start,
                    ),
                  ),
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  changes.add(args.$2);
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final executor = awaitingFood
                ? BolusThenWaitExecutor()
                : DetectFinishedEatingExecutor(shouldBolus: false);
            var finished = false;
            unawaited(
              executor
                  .execute(
                    harness.runtimeContext,
                    MealMonitorContext(activeMeal: meal),
                  )
                  .then((_) {
                    finished = true;
                  }),
            );
            async.flushMicrotasks();
            if (!awaitingFood) {
              async.elapse(const Duration(minutes: 5));
              harness.dispatchTick(clock.now());
              async.flushMicrotasks();
            }
            harness.dispatchEvent(
              awaitingFood
                  ? const EatNowResponseEvent.eating(mealId: 1)
                  : const FinishedEatingResponseEvent.agree(mealId: 1),
            );
            async.flushMicrotasks();
            expect(changes, isEmpty);
            expect(finished, isFalse);
            harness.dispatchEvent(
              awaitingFood
                  ? const EatNowResponseEvent.eating(mealId: 2)
                  : const FinishedEatingResponseEvent.agree(mealId: 2),
            );
            async.flushMicrotasks();
            expect(changes, [awaitingFood ? 'waited-eating' : 'eaten']);
            expect(finished, isTrue);
            harness.cancel();
            async.flushMicrotasks();
            container.dispose();
          });
        });
      },
    );
  }

  for (final eatBeforeBolus in [true, false]) {
    test(
      'bolus reminder uses ${eatBeforeBolus ? 'fresh consumed' : 'planned'} carbs',
      () {
        fakeAsync((async) {
          final start = DateTime(2026, 11, 1, 12);
          withClock(Clock(() => start.add(async.elapsed)), () {
            final meal = Meal(
              id: 1,
              name: 'Lunch',
              status: 'waiting-for-bolus',
              plannedAt: start,
            );
            var consumedCarbs = 50.0;
            final notifications = PendingNotificationsController();
            final container = ProviderContainer(
              overrides: [
                notificationsControllerForegroundProvider.overrideWithValue(
                  notifications,
                ),
                mealMacronutrientsSummaryProvider(
                  1,
                ).overrideWith((ref) async => completionTestMacros(50)),
                mealMacronutrientsConsumedSummaryProvider(1).overrideWith(
                  (ref) async => completionTestMacros(consumedCarbs),
                ),
              ],
            );
            final subscription = container.listen(
              mealMacronutrientsConsumedSummaryProvider(1),
              (_, _) {},
            );
            async.flushMicrotasks();
            expect(
              container
                  .read(mealMacronutrientsConsumedSummaryProvider(1))
                  .value
                  ?.netCarbsGrams,
              50,
            );
            consumedCarbs = 10;
            final harness = FakeRuntimeHarness(container: container);
            final executor = WaitForBolusExecutor(
              initialAdvice: MealAdvice.full(
                eatBeforeBolus
                    ? MealDecision.eatNowBolusLater
                    : MealDecision.bolusAndEatNow,
                null,
                start,
              ),
            );
            unawaited(
              executor
                  .execute(
                    harness.runtimeContext,
                    MealMonitorContext(activeMeal: meal),
                  )
                  .then<void>((_) {})
                  .catchError((Object error) {
                    if (error is! TaskCancelledException) throw error;
                  }),
            );
            async.flushMicrotasks();
            final reminder = notifications.shownEvents
                .whereType<MealSuggestionNotificationEvent>()
                .single;
            expect(reminder.carbs, eatBeforeBolus ? 10 : 50);
            harness.cancel();
            async.flushMicrotasks();
            subscription.close();
            container.dispose();
          });
        });
      },
    );
  }
}

MealMacroSummary completionTestMacros(double carbs) => MealMacroSummary(
  carbsGrams: carbs,
  fatGrams: 0,
  proteinGrams: 0,
  fiberGrams: 0,
  totalGrams: carbs * 5,
);
