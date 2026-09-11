import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/event/internal/meal_event.dart';
import 'package:diabeatthis/foreground/event/internal/meal_status_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  for (final disposeDuringDelay in [false, true]) {
    test(
      'does not emit a candidate ${disposeDuringDelay ? 'after disposal' : 'that changed during the delay'}',
      () async {
        final now = DateTime.now();
        final db = drift.DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        for (final id in [1, 2]) {
          await db.customInsert(
            "INSERT INTO meal (id, name, planned_at, status) VALUES (?, 'Meal', ?, 'planned')",
            variables: [
              Variable<int>(id),
              Variable<int>(
                now.add(Duration(hours: id)).millisecondsSinceEpoch,
              ),
            ],
          );
        }
        fakeAsync((async) {
          withClock(Clock(() => now.add(async.elapsed)), () {
            final container = ProviderContainer(
              overrides: [databaseProvider.overrideWithValue(db)],
            );
            final harness = FakeRuntimeHarness(container: container);
            final collector = NextMealCollector();
            collector.start(
              CollectorContext.fromRuntimeContext(harness.runtimeContext),
            );
            async.flushMicrotasks();
            expect(harness.emittedEvents.whereType<NextMealEvent>(), isEmpty);
            async.elapse(const Duration(milliseconds: 500));
            if (disposeDuringDelay) {
              unawaited(collector.dispose());
            } else {
              unawaited(db.mealDao.updateMealStatus(1, 'waiting-for-bolus'));
            }
            async.flushMicrotasks();
            async.elapse(const Duration(milliseconds: 500));
            expect(harness.emittedEvents.whereType<NextMealEvent>(), isEmpty);
            async.elapse(const Duration(seconds: 1));
            final events = harness.emittedEvents.whereType<NextMealEvent>();
            if (disposeDuringDelay) {
              expect(events, isEmpty);
            } else {
              expect(events, hasLength(1));
              expect(events.single.mealId, 2);
            }
            unawaited(collector.dispose());
            async.flushMicrotasks();
            harness.cancel();
            async.flushMicrotasks();
            container.dispose();
            unawaited(db.close());
            async.elapse(Duration.zero);
            async.flushMicrotasks();
          });
        });
      },
    );
  }

  for (final duringTransition in [true, false]) {
    test(
      'delays next meal discovered ${duringTransition ? 'during transition' : 'after transition'} without interrupting bolus wait',
      () async {
        final now = DateTime.now();
        final db = drift.DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customInsert(
          "INSERT INTO meal (id, name, planned_at, status) VALUES (82, 'Dinner', ?, 'planned')",
          variables: [
            Variable<int>(
              now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
            ),
          ],
        );
        fakeAsync((async) {
          withClock(Clock(() => now.add(async.elapsed)), () {
            final plannedMeal = Meal(
              id: 84,
              name: 'Lunchbox',
              status: 'planned',
              plannedAt: now.add(const Duration(hours: 2)),
              carbs: 20,
            );
            final waitingMeal = plannedMeal.copyWith(
              status: 'waiting-for-bolus',
              updatedAt: now,
            );
            final mealRead = Completer<Meal>();
            final updates = <(int, String)>[];
            final notifications = FakeNotificationsController();
            var nextMealReads = 0;
            final container = ProviderContainer(
              overrides: [
                databaseProvider.overrideWithValue(db),
                getNearestMealProvider.overrideWithValue(
                  AsyncData(plannedMeal),
                ),
                getMealByIdProvider(84).overrideWith((ref) => mealRead.future),
                getMealByIdProvider(82).overrideWith((ref) async {
                  nextMealReads++;
                  return Meal(
                    id: 82,
                    name: 'Dinner',
                    status: 'planned',
                    plannedAt: now.add(const Duration(hours: 3)),
                  );
                }),
                getMealAdviceProvider(waitingMeal).overrideWithValue(
                  AsyncData(
                    MealAdvice.full(MealDecision.bolusAndEatNow, null, now),
                  ),
                ),
                notificationsControllerForegroundProvider.overrideWithValue(
                  notifications,
                ),
                updateMealProvider.overrideWith((ref, args) async {
                  updates.add((args.$1.id, args.$2));
                }),
              ],
            );
            final harness = FakeRuntimeHarness(container: container);
            final task = MealMonitorTask();
            task.run(harness.runtimeContext).catchError((Object error) {
              if (error is! TaskCancelledException) throw error;
            });
            async.flushMicrotasks();
            expect(task.state, isA<MonitorUntilMeal>());
            expect(
              task.shouldInterrupt(
                NextMealEvent(82, now.add(const Duration(hours: 3))),
              ),
              isTrue,
            );

            harness.dispatchEventToTask(
              task,
              MealWaitingForBolusEvent(mealId: 84),
            );
            async.flushMicrotasks();
            // Hold the database read while the bolus transition is pending.
            expect(task.state, isA<MonitorUntilMeal>());
            final nextMeal = NextMealEvent(
              82,
              now.add(const Duration(hours: 3)),
            );
            var interruptedByNextMeal = false;
            harness.interruptController.onInterrupt.then((_) {
              interruptedByNextMeal = true;
            });
            final collector = NextMealCollector();
            final emittedNextMeals = <NextMealEvent>[];
            final runtime = harness.runtimeContext;
            final collectorContext = CollectorContext(
              container: container,
              emitEvent: (event) {
                if (event is NextMealEvent) emittedNextMeals.add(event);
                harness.dispatchEventToTask(task, event);
              },
              emitSignal: runtime.emitSignal,
              waitForDuration: runtime.waitForDuration,
              waitForSignal: runtime.waitForSignal,
              durationWait: runtime.durationWait,
              signalWait: runtime.signalWait,
            );
            if (duringTransition) {
              collector.start(collectorContext);
              async.flushMicrotasks();
              expect(emittedNextMeals, isEmpty);
            }
            mealRead.complete(waitingMeal);
            async.flushMicrotasks();
            expect(task.state, isA<WaitForBolusExecutor>());

            if (!duringTransition) {
              expect(task.shouldInterrupt(nextMeal), isFalse);
              collector.start(collectorContext);
              async.flushMicrotasks();
            }
            async.elapse(const Duration(milliseconds: 999));
            expect(emittedNextMeals, isEmpty);
            async.elapse(const Duration(milliseconds: 1));
            expect(emittedNextMeals, hasLength(1));
            expect(emittedNextMeals.single.mealId, 82);
            expect(task.shouldInterrupt(emittedNextMeals.single), isFalse);
            expect(nextMealReads, 0);
            expect(interruptedByNextMeal, isFalse);
            expect(notifications.shownEvents, hasLength(1));
            expect(updates, isEmpty);

            harness.dispatchEventToTask(
              task,
              TreatmentAvailableEvent<BolusWizard>(
                BolusWizard(
                  nightscoutObjectId: null,
                  createdAt: now,
                  date: now,
                  glucose: 120,
                  units: 'mg/dl',
                  notes: null,
                  calculatorResult: null,
                ),
              ),
            );
            async.flushMicrotasks();
            expect(updates, [(84, 'bolused-eating')]);
            expect(task.state, isA<DetectFinishedEatingExecutor>());
            expect(nextMealReads, 0);

            unawaited(collector.dispose());
            async.flushMicrotasks();
            harness.cancel();
            async.flushMicrotasks();
            container.dispose();
            unawaited(db.close());
            async.elapse(Duration.zero);
            async.flushMicrotasks();
          });
        });
      },
    );
  }
}
