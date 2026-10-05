import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/foreground/event/internal/meal_event.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  for (final minutes in [45, 180]) {
    test('reloads the same meal rescheduled to $minutes minutes from now', () {
      fakeAsync((async) {
        final now = DateTime(2026, 9, 17, 8);
        withClock(Clock.fixed(now), () {
          final original = Meal(
            id: 1,
            name: 'Breakfast',
            status: 'planned',
            plannedAt: now.add(const Duration(hours: 2)),
          );
          var persistedMeal = original;
          var reads = 0;
          final container = ProviderContainer(
            overrides: [
              getNearestMealProvider.overrideWithValue(AsyncData(original)),
              getMealByIdProvider(1).overrideWith((ref) async {
                reads++;
                return persistedMeal;
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
            task.shouldInterrupt(NextMealEvent(1, original.plannedAt!)),
            isFalse,
          );

          // Prime the provider cache to verify that the restart reloads it.
          container.read(getMealByIdProvider(1));
          async.flushMicrotasks();
          expect(reads, 1);
          final newTime = now.add(Duration(minutes: minutes));
          persistedMeal = original.copyWith(plannedAt: newTime);
          harness.dispatchEventToTask(task, NextMealEvent(1, newTime));
          async.flushMicrotasks();

          expect(reads, 2);
          expect(task.state, isA<MonitorUntilMeal>());
          expect(
            harness.emittedEvents
                .whereType<MealMonitoringStatusChanged>()
                .last
                .status
                .plannedAt,
            newTime,
          );
          expect(task.shouldInterrupt(NextMealEvent(1, newTime)), isFalse);
          expect(
            task.shouldInterrupt(NextMealEvent(1, original.plannedAt!)),
            isTrue,
          );

          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    });
  }
}
