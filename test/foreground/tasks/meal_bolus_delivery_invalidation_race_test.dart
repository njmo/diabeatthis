import 'dart:async';

import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/wait_for_meal_bolus_delivery.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/paused_bolus_evidence_query.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  for (final stage in ['read', 'write', 'commit']) {
    for (final target in ['wizard', 'delivery']) {
      test(
        '$target invalidated during $stage never confirms or leaves invalid evidence',
        () async {
          final pause = PausedBolusEvidenceQuery(stage);
          final db = DatabaseImpl(NativeDatabase.memory().interceptWith(pause));
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
          final waitingAgain = Completer<void>();
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              mealBolusDeliveryHistoryProvider.overrideWithValue((_) async {
                if (!waitingAgain.isCompleted) waitingAgain.complete();
                return [];
              }),
            ],
          );
          container.read(databaseProvider);
          final harness = FakeRuntimeHarness(container: container);
          harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
          pause.armed = true;
          CalculatorSubmission? confirmed;
          final waiting =
              const WaitForMealBolusDelivery()(
                    harness.runtimeContext,
                    MealMonitorContext(
                      activeMeal: Meal(
                        id: 91,
                        name: 'Meal',
                        status: 'waiting-for-bolus',
                      ),
                    ),
                    wizard,
                  )
                  .then<void>((value) {
                    confirmed = value;
                  })
                  .catchError((Object error) {
                    if (error is! TaskCancelledException) throw error;
                  });
          addTearDown(() async {
            if (!pause.resume.isCompleted) pause.resume.complete();
            harness.cancel();
            await waiting;
            container.dispose();
            await db.close();
          });
          await pause.reached.future.timeout(const Duration(seconds: 5));
          if (target == 'wizard') {
            harness.dispatchEvent(
              TreatmentAvailableEvent<BolusWizard>(
                wizard.copyWith(isValid: false),
              ),
            );
          } else {
            harness.dispatchEvent(
              TreatmentAvailableEvent<ManualBolus>(
                delivery.copyWith(isValid: false),
              ),
            );
          }
          pause.resume.complete();
          await waitingAgain.future.timeout(const Duration(seconds: 5));
          expect(confirmed, isNull);
          if (target == 'wizard') {
            expect(await db.select(db.bolusWizard).get(), isEmpty);
          } else {
            expect(await db.select(db.manualBolus).get(), isEmpty);
          }
        },
      );
    }
  }

  test(
    'corrected calculator during persistence replaces stale values and is returned',
    () async {
      final pause = PausedBolusEvidenceQuery('write');
      final db = DatabaseImpl(NativeDatabase.memory().interceptWith(pause));
      await db.customSelect('SELECT 1').get();
      final start = DateTime.utc(2026, 1, 1, 12);
      final wizard = testBolusWizard(
        createdAt: start,
        carbs: 48,
        insulin: 44.7,
      );
      final corrected = wizard.copyWith(
        calculatorResult: wizard.calculatorResult!.copyWith(
          carbs: 13,
          totalInsulin: 24.2,
        ),
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
      container.read(databaseProvider);
      final harness = FakeRuntimeHarness(container: container);
      harness.dispatchEvent(TreatmentAvailableEvent<ManualBolus>(delivery));
      pause.armed = true;
      final waiting = const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        MealMonitorContext(
          activeMeal: Meal(id: 91, name: 'Meal', status: 'waiting-for-bolus'),
        ),
        wizard,
      );
      await pause.reached.future.timeout(const Duration(seconds: 5));
      harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(corrected));
      pause.resume.complete();
      final confirmed = await waiting.timeout(const Duration(seconds: 5));
      expect(confirmed.wizard, corrected);
      expect(confirmed.deliveredInsulin, 3);
      final stored = (await db.select(db.bolusWizard).get()).single;
      expect(stored.carbs, 13);
      expect(stored.insulin, 24.2);
      expect((await db.select(db.manualBolus).get()).single.insulin, 3);
      harness.cancel();
      container.dispose();
      await db.close();
    },
  );
}
