import 'package:clock/clock.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/activity_monitor_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/idle_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/monitor_until_meal.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'identical status is emitted once while metadata changes are preserved',
    () async {
      final harness = FakeRuntimeHarness();
      final meal = MealMonitorContext(
        activeMeal: const Meal(id: 1, name: 'Obiad'),
      );
      meal.publishStatus(
        harness.runtimeContext,
        MealMonitoringPhase.waitingForBolus,
      );
      meal.publishStatus(
        harness.runtimeContext,
        MealMonitoringPhase.waitingForBolus,
      );
      meal.activeMeal = meal.activeMeal!.copyWith(name: 'Kolacja');
      meal.publishStatus(
        harness.runtimeContext,
        MealMonitoringPhase.waitingForBolus,
      );
      meal.publishStatus(harness.runtimeContext, MealMonitoringPhase.idle);
      meal.publishStatus(harness.runtimeContext, MealMonitoringPhase.idle);
      final events = harness.emittedEvents
          .whereType<MealMonitoringStatusChanged>()
          .toList();
      expect(events, hasLength(3));
      expect(events[1].status.name, 'Kolacja');
      expect(events.last.status.mealId, isNull);
      final activity = ActivityMonitorContext(
        activityLogId: 1,
        activityName: 'Spacer',
      );
      activity.publishStatus(
        harness.runtimeContext,
        ActivityMonitoringPhase.active,
      );
      activity.publishStatus(
        harness.runtimeContext,
        ActivityMonitoringPhase.active,
      );
      activity.activityLogId = 2;
      activity.publishStatus(
        harness.runtimeContext,
        ActivityMonitoringPhase.active,
      );
      expect(
        harness.emittedEvents.whereType<ActivityMonitoringStatusChanged>(),
        hasLength(2),
      );
      await harness.dispose();
    },
  );

  test('near-term meal remains visible while waiting for the user', () async {
    final now = DateTime(2026, 9, 9, 12);
    await withClock(Clock.fixed(now), () async {
      final harness = FakeRuntimeHarness();
      harness.container
          .read(deviceStatusValueProvider.notifier)
          .update(
            testDeviceStatus(date: now, iob: 0, cob: 0, tick: '+0', bg: 100),
          );
      final meal = MealMonitorContext(
        activeMeal: Meal(id: 1, name: 'Obiad', plannedAt: now),
      );
      final executor = await MonitorUntilMeal().execute(
        harness.runtimeContext,
        meal,
      );
      expect(executor, isA<MealMonitorStateIdle>());
      final running = executor.execute(harness.runtimeContext, meal);
      final event = harness.emittedEvents
          .whereType<MealMonitoringStatusChanged>()
          .last;
      expect(event.status.phase, MealMonitoringPhase.waitingForUser);
      expect(event.status.name, 'Obiad');
      final cancelled = expectLater(
        running,
        throwsA(isA<TaskCancelledException>()),
      );
      await harness.dispose();
      await cancelled;
    });
  });
}
