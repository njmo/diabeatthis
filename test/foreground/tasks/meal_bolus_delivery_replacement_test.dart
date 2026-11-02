import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/meal_monitor_state_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  test(
    'initial meal accepts the later delivered submission after a zero calculator',
    () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 2, 14, 55, 35, 306);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final zero = testBolusWizard(createdAt: start, carbs: 48, insulin: 0);
          final replacement = testBolusWizard(
            createdAt: DateTime.utc(2026, 11, 2, 15, 15, 13, 766),
            carbs: 48,
            insulin: 43.8,
          );
          final delivery = ManualBolus(
            externalId: 'replacement-delivery',
            createdAt: DateTime.utc(2026, 11, 2, 15, 15, 16, 164),
            insulin: 3,
          );
          final meal = Meal(
            id: 91,
            name: 'Meal',
            status: 'waiting-for-bolus',
            carbs: 48,
          );
          final updates = <String>[];
          final linked = <BolusWizard>[];
          final container = ProviderContainer(
            overrides: [
              mealWizardRecorderProvider.overrideWithValue((
                wizard,
                _,
                _,
              ) async {
                linked.add(wizard);
              }),
              mealBolusDeliveryHistoryProvider.overrideWithValue(
                (_) async => [],
              ),
              notificationsControllerForegroundProvider.overrideWithValue(
                FakeNotificationsController(),
              ),
              getMealAdviceProvider(meal).overrideWithValue(
                AsyncData(
                  MealAdvice.full(MealDecision.eatNowBolusLater, null, start),
                ),
              ),
              updateMealProvider.overrideWith((ref, args) async {
                updates.add(args.$2);
              }),
            ],
          );
          container.read(latestBolusWizardProvider.notifier).update(zero);
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
          expect(updates, isEmpty);
          async.elapse(replacement.createdAt.difference(start));
          harness.dispatchEvent(
            TreatmentAvailableEvent<BolusWizard>(replacement),
          );
          async.flushMicrotasks();
          expect(updates, isEmpty);
          harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
          async.flushMicrotasks();
          final pendingZero = container
              .read(calculatorSubmissionsProvider)
              .singleWhere((item) => item.wizard.createdAt == zero.createdAt);
          final actualUpdates = List<String>.of(updates);
          final actualLinked = List<BolusWizard>.of(linked);
          final actualNext = next;
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
          expect(pendingZero.delivery, isNull);
          expect(actualUpdates, ['eaten-bolused']);
          expect(actualLinked, [replacement]);
          expect(actualNext, isA<FinalizeMealExecutor>());
        });
      });
    },
  );
}
