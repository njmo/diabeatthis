import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/detect_finished_eating_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/meal_monitor_state_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';

void main() {
  for (final hasUpdatedAt in [true, false]) {
    for (final age in [
      const Duration(minutes: 4, seconds: 59),
      const Duration(minutes: 5),
      const Duration(minutes: 5, milliseconds: 1),
    ]) {
      for (final decision in [
        MealDecision.bolusAndEatNow,
        MealDecision.eatNowBolusLater,
      ]) {
        test(
          'cached wizard age ${age.inMilliseconds}ms for $decision with updatedAt=$hasUpdatedAt',
          () {
            fakeAsync((async) {
              final statusChangedAt = DateTime(2026, 9, 11, 12);
              // A delayed executor must use the status timestamp when available.
              final now = hasUpdatedAt
                  ? statusChangedAt.add(const Duration(seconds: 30))
                  : statusChangedAt;
              withClock(Clock.fixed(now), () {
                final meal = Meal(
                  id: 84,
                  name: 'Lunchbox',
                  status: 'waiting-for-bolus',
                  carbs: 20,
                  updatedAt: hasUpdatedAt ? statusChangedAt : null,
                );
                final wizard = BolusWizard(
                  nightscoutObjectId: null,
                  createdAt: statusChangedAt.subtract(age),
                  date: statusChangedAt.subtract(age),
                  glucose: 120,
                  units: 'mg/dl',
                  notes: null,
                  calculatorResult: null,
                );
                final notifications = FakeNotificationsController();
                final updates = <(int, String)>[];
                final container = ProviderContainer(
                  overrides: [
                    notificationsControllerForegroundProvider.overrideWithValue(
                      notifications,
                    ),
                    getMealAdviceProvider(meal).overrideWithValue(
                      AsyncData(MealAdvice.full(decision, null, now)),
                    ),
                    updateMealProvider.overrideWith((ref, args) async {
                      updates.add((args.$1.id, args.$2));
                    }),
                  ],
                );
                container
                    .read(latestBolusWizardProvider.notifier)
                    .update(wizard);
                final harness = FakeRuntimeHarness(container: container);
                MealMonitorStateExecutor? next;
                WaitForBolusExecutor()
                    .execute(
                      harness.runtimeContext,
                      MealMonitorContext(activeMeal: meal),
                    )
                    .then((value) {
                      next = value;
                    })
                    .catchError((Object error) {
                      if (error is! TaskCancelledException) throw error;
                    });
                async.flushMicrotasks();
                final expectedStatus = decision == MealDecision.eatNowBolusLater
                    ? 'eaten-bolused'
                    : 'bolused-eating';
                if (age <= const Duration(minutes: 5)) {
                  expect(updates, [(84, expectedStatus)]);
                  expect(notifications.shownEvents, isEmpty);
                } else {
                  expect(updates, isEmpty);
                  expect(next, isNull);
                  expect(notifications.shownEvents, hasLength(1));
                  // Rejecting the old cache must still allow a later calculator event.
                  harness.dispatchEvent(
                    TreatmentAvailableEvent<BolusWizard>(
                      wizard.copyWith(createdAt: now, date: now),
                    ),
                  );
                  async.flushMicrotasks();
                  expect(updates, [(84, expectedStatus)]);
                }
                expect(container.read(latestBolusWizardProvider), isNull);
                expect(
                  next,
                  decision == MealDecision.eatNowBolusLater
                      ? isA<FinalizeMealExecutor>()
                      : isA<DetectFinishedEatingExecutor>(),
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
  }
}
