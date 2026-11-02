import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
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
    'first zero calculator advances the meal only after its carbs arrive',
    () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 2, 16, 25, 12, 746);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final wizard = testBolusWizard(
            createdAt: start,
            carbs: 12,
            insulin: 0,
          );
          final meal = Meal(
            id: 91,
            name: 'Meal',
            status: 'waiting-for-bolus',
            carbs: 12,
          );
          final updates = <String>[];
          final linked = <BolusWizard>[];
          final container = ProviderContainer(
            overrides: [
              mealWizardRecorderProvider.overrideWithValue((
                record,
                _,
                _,
              ) async {
                linked.add(record);
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
          final harness = FakeRuntimeHarness(container: container);
          container.read(latestBolusWizardProvider.notifier).update(wizard);
          MealMonitorStateExecutor? next;
          WaitForBolusExecutor()
              .execute(
                harness.runtimeContext,
                MealMonitorContext(activeMeal: meal),
              )
              .then((value) {
                next = value;
              });
          async.flushMicrotasks();
          expect(updates, isEmpty);
          expect(linked, isEmpty);
          expect(next, isNull);

          async.elapse(const Duration(seconds: 1));
          TreatmentEventDispatcher().dispatch(
            container: container,
            emitEvent: harness.dispatchEvent,
            treatment: Treat(
              externalId: 'confirmed-carbs',
              createdAt: start.add(const Duration(milliseconds: 849)),
              carbs: 12,
            ),
          );
          async.flushMicrotasks();
          expect(updates, ['eaten-bolused']);
          expect(linked, hasLength(1));
          expect(linked.single.createdAt, wizard.createdAt);
          expect(linked.single.carbohydrateRecord?.carbs, 12);
          expect(next, isA<FinalizeMealExecutor>());
          final submission = container
              .read(calculatorSubmissionsProvider)
              .single;
          expect(submission.isComplete, isTrue);
          expect(submission.delivery, isNull);
          expect(submission.deliveredInsulin, isNull);
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    },
  );
}
