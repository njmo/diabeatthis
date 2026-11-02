import 'package:clock/clock.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/event/internal/monitoring_status_changed.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/finalize_meal_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/meal_monitor_state_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/executors/wait_for_bolus_executor.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/wait_for_meal_bolus_delivery.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_notifications_controller.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  test(
    'accepted live delivery survives a cleared cache without bulk mirroring',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final start = DateTime.utc(2026, 1, 1, 12);
      final wizard = testBolusWizard(
        createdAt: start,
        carbs: 48,
        insulin: 44.7,
      );
      final delivery = ManualBolus(
        externalId: 'actual',
        createdAt: start.add(const Duration(milliseconds: 830)),
        insulin: 3,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          mealBolusDeliveryHistoryProvider.overrideWithValue((_) async => []),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      container.read(databaseProvider);
      harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
      final context = MealMonitorContext(
        activeMeal: Meal(id: 91, name: 'Meal', status: 'waiting-for-bolus'),
      );
      final accepted = await const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        context,
        wizard,
      );
      expect(accepted.deliveredInsulin, 3);
      expect((await db.select(db.manualBolus).get()).single.insulin, 3);
      container.invalidate(calculatorSubmissionsProvider);
      expect(container.read(calculatorSubmissionsProvider), isEmpty);
      final recovered = await const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        context,
        wizard,
      );
      expect(recovered.deliveredInsulin, 3);
      expect(recovered.recommendedInsulin, 44.7);
      harness.cancel();
      container.dispose();
      await db.close();
    },
  );

  test('configured history confirms delivery without a local mirror', () async {
    final start = DateTime.utc(2026, 1, 1, 12);
    final wizard = testBolusWizard(createdAt: start, carbs: 13, insulin: 24.2);
    final delivery = ManualBolus(
      externalId: 'cloud-actual',
      createdAt: start.add(const Duration(milliseconds: 798)),
      insulin: 3,
    );
    final container = ProviderContainer(
      overrides: [
        mealBolusDeliveryHistoryProvider.overrideWithValue(
          (_) async => [wizard, delivery],
        ),
      ],
    );
    final harness = FakeRuntimeHarness(container: container);
    final context = MealMonitorContext(
      activeMeal: Meal(id: 92, name: 'Meal', status: 'waiting-for-bolus'),
    );
    final result = await const WaitForMealBolusDelivery()(
      harness.runtimeContext,
      context,
      wizard,
    );
    expect(result.deliveredInsulin, 3);
    expect(
      container.read(calculatorSubmissionsProvider).single.deliveredInsulin,
      3,
    );
    harness.cancel();
    container.dispose();
  });

  test(
    'wizard alone remains pending until actual delivery arrives minutes later',
    () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 1, 1, 12);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final wizard = testBolusWizard(
            createdAt: start,
            carbs: 48,
            insulin: 44.7,
          );
          final meal = Meal(
            id: 91,
            name: 'Meal',
            status: 'waiting-for-bolus',
            carbs: 48,
          );
          final updates = <String>[];
          final container = ProviderContainer(
            overrides: [
              mealWizardRecorderProvider.overrideWithValue((_, _, _) async {}),
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
          container.read(latestBolusWizardProvider.notifier).update(wizard);
          final harness = FakeRuntimeHarness(container: container);
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
          expect(next, isNull);
          expect(
            harness.emittedEvents
                .whereType<MealMonitoringStatusChanged>()
                .last
                .status
                .phase,
            MealMonitoringPhase.waitingForDeliveryConfirmation,
          );

          async.elapse(const Duration(minutes: 2));
          harness.dispatchTick(clock.now());
          async.flushMicrotasks();
          expect(updates, isEmpty);
          final delivery = ManualBolus(
            externalId: 'actual-delivery',
            createdAt: start.add(const Duration(milliseconds: 830)),
            insulin: 3,
          );
          harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
          async.flushMicrotasks();
          expect(updates, ['eaten-bolused']);
          expect(next, isA<FinalizeMealExecutor>());
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    },
  );

  test('unconfirmed or invalid delivery cannot finalize a cancelled wait', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 1, 1, 12);
      withClock(Clock.fixed(start), () {
        final wizard = testBolusWizard(
          createdAt: start,
          carbs: 13,
          insulin: 24.2,
        );
        final meal = Meal(
          id: 92,
          name: 'Meal',
          status: 'waiting-for-bolus',
          carbs: 13,
        );
        final updates = <String>[];
        final container = ProviderContainer(
          overrides: [
            mealWizardRecorderProvider.overrideWithValue((_, _, _) async {}),
            mealBolusDeliveryHistoryProvider.overrideWithValue((_) async => []),
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
        container.read(latestBolusWizardProvider.notifier).update(wizard);
        final harness = FakeRuntimeHarness(container: container);
        var cancelled = false;
        WaitForBolusExecutor()
            .execute(
              harness.runtimeContext,
              MealMonitorContext(activeMeal: meal),
            )
            .catchError((Object error) {
              if (error is! TaskCancelledException) throw error;
              cancelled = true;
              return FinalizeMealExecutor();
            });
        async.flushMicrotasks();
        for (final delivery in [
          ManualBolus(externalId: 'zero', createdAt: start, insulin: 0),
          ManualBolus(
            externalId: 'invalid',
            createdAt: start,
            insulin: 3,
            isValid: false,
          ),
          ManualBolus(
            externalId: 'unrelated',
            createdAt: start.add(const Duration(minutes: 1)),
            insulin: 3,
          ),
        ]) {
          harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
          async.flushMicrotasks();
        }
        expect(updates, isEmpty);
        harness.cancel();
        async.flushMicrotasks();
        expect(cancelled, isTrue);
        expect(updates, isEmpty);
        container.dispose();
      });
    });
  });
}
