import 'dart:async';

import 'package:diabeatthis/common/meal/meal_calculator_submission.dart';
import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/wait_for_meal_bolus_delivery.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/paused_carbohydrate_evidence_query.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  for (final (stage, target) in [
    ('read', 'carbs'),
    ('write', 'carbs'),
    ('commit', 'carbs'),
    ('commit', 'delivery'),
  ]) {
    test(
      '$target invalidated during $stage cannot confirm zero submission or survive restart',
      () async {
        final pause = PausedCarbohydrateEvidenceQuery(stage);
        final db = DatabaseImpl(NativeDatabase.memory().interceptWith(pause));
        await db.customSelect('SELECT 1').get();
        final start = DateTime(2026, 11, 2, 17, 25, 12);
        final wizard = testBolusWizard(createdAt: start, carbs: 12, insulin: 0);
        final carbs = Treat(
          externalId: 'component',
          createdAt: start.add(const Duration(milliseconds: 830)),
          carbs: 12,
        );
        final delivery = ManualBolus(
          externalId: 'actual',
          createdAt: start.add(const Duration(milliseconds: 800)),
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
        final dispatcher = TreatmentEventDispatcher();
        for (final treatment in [
          wizard,
          if (target == 'delivery') delivery,
          carbs,
        ]) {
          dispatcher.dispatch(
            container: container,
            emitEvent: harness.dispatchEvent,
            treatment: treatment,
          );
        }
        CalculatorSubmission? confirmed;
        final waiting =
            const WaitForMealBolusDelivery()(
                  harness.runtimeContext,
                  MealMonitorContext(
                    activeMeal: Meal(
                      id: 1,
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
        dispatcher.dispatch(
          container: container,
          emitEvent: harness.dispatchEvent,
          treatment: target == 'delivery'
              ? delivery.copyWith(isValid: false)
              : carbs.copyWith(isValid: false),
        );
        pause.resume.complete();
        await waitingAgain.future.timeout(const Duration(seconds: 5));
        expect(confirmed, isNull);
        for (final stored in await db.select(db.bolusWizard).get()) {
          expect(
            (await readMealCalculatorSubmission(
              db,
              stored.toDomain(),
            )).isComplete,
            isFalse,
          );
          if (target == 'delivery') {
            expect(stored.toDomain().hasUnresolvedDelivery, isTrue);
          }
        }
        expect(await db.select(db.manualBolus).get(), isEmpty);
        expect(await db.select(db.treat).get(), isEmpty);
      },
    );
  }
}
