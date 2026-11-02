import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/wait_for_meal_bolus_delivery.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_context.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/callback_treatments_history_repository.dart';
import '../utils/fake_runtime_harness.dart';
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  final start = DateTime.utc(2026, 11, 2, 14, 55, 35, 306);
  final zero = testBolusWizard(createdAt: start, carbs: 48, insulin: 0);
  final replacement = testBolusWizard(
    createdAt: DateTime.utc(2026, 11, 2, 15, 15, 13, 766),
    carbs: 48,
    insulin: 43.8,
  );
  final delivery = ManualBolus(
    externalId: 'actual',
    createdAt: replacement.createdAt.add(const Duration(milliseconds: 2398)),
    insulin: 3,
  );
  MealMonitorContext context() => MealMonitorContext(
    activeMeal: Meal(id: 91, name: 'Meal', status: 'waiting-for-bolus'),
  );

  test(
    'cloud-only history finds a later confirmed replacement outside the first submission window',
    () async {
      final reads = <(DateTime, DateTime)>[];
      final container = ProviderContainer(
        overrides: [
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async =>
                CallbackTreatmentsHistoryRepository((from, until) async {
                  reads.add((from, until));
                  return <Treatment>[zero, replacement, delivery]
                      .where(
                        (record) =>
                            !record.createdAt!.isBefore(from) &&
                            !record.createdAt!.isAfter(until),
                      )
                      .toList();
                }),
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(() {
        harness.cancel();
        container.dispose();
      });
      final confirmed = await withClock(
        Clock.fixed(replacement.createdAt.add(const Duration(seconds: 10))),
        () => const WaitForMealBolusDelivery()(
          harness.runtimeContext,
          context(),
          zero,
        ),
      ).timeout(const Duration(seconds: 5));
      expect(confirmed.wizard, replacement);
      expect(confirmed.deliveredInsulin, 3);
      expect(reads.single.$1.isBefore(zero.createdAt), isTrue);
      expect(reads.single.$2.isAfter(delivery.createdAt), isTrue);
      expect(
        container.read(calculatorSubmissionsProvider).first.delivery,
        isNull,
      );
    },
  );

  test(
    'source refresh can correct a cached pending calculator without bulk mirroring',
    () async {
      final corrected = zero.copyWith(
        calculatorResult: zero.calculatorResult!.copyWith(
          carbs: 13,
          totalInsulin: 24.2,
        ),
      );
      final actual = delivery.copyWith(
        createdAt: start.add(const Duration(milliseconds: 830)),
      );
      final container = ProviderContainer(
        overrides: [
          mealBolusDeliveryHistoryProvider.overrideWithValue(
            (_) async => [corrected, actual],
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(() {
        harness.cancel();
        container.dispose();
      });
      final confirmed = await const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        context(),
        zero,
      ).timeout(const Duration(seconds: 5));
      expect(confirmed.wizard, corrected);
      expect(confirmed.deliveredInsulin, 3);
    },
  );

  test(
    'source refresh invalidates a cached pending calculator before selecting its replacement',
    () async {
      final container = ProviderContainer(
        overrides: [
          mealBolusDeliveryHistoryProvider.overrideWithValue(
            (_) async => [zero.copyWith(isValid: false), replacement, delivery],
          ),
        ],
      );
      final harness = FakeRuntimeHarness(container: container);
      addTearDown(() {
        harness.cancel();
        container.dispose();
      });
      final confirmed = await const WaitForMealBolusDelivery()(
        harness.runtimeContext,
        context(),
        zero,
      ).timeout(const Duration(seconds: 5));
      expect(confirmed.wizard, replacement);
      expect(
        container.read(calculatorSubmissionsProvider).first.isValid,
        isFalse,
      );
    },
  );

  for (final invalidated in [false, true]) {
    test(
      'a source snapshot does not overwrite a live ${invalidated ? 'invalidation' : 'correction'} received during its read',
      () async {
        final reached = Completer<void>();
        final refresh = Completer<List<Treatment>>();
        final waitingAgain = Completer<void>();
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            mealBolusDeliveryHistoryProvider.overrideWithValue((_) {
              if (reads++ == 0) {
                reached.complete();
                return refresh.future;
              }
              if (!waitingAgain.isCompleted) waitingAgain.complete();
              return Future.value([]);
            }),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        CalculatorSubmission? confirmed;
        final waiting =
            const WaitForMealBolusDelivery()(
                  harness.runtimeContext,
                  context(),
                  zero,
                )
                .then<void>((value) {
                  confirmed = value;
                })
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                });
        addTearDown(() async {
          harness.cancel();
          await waiting;
          container.dispose();
        });
        await reached.future.timeout(const Duration(seconds: 5));
        final actual = delivery.copyWith(
          createdAt: start.add(const Duration(milliseconds: 830)),
        );
        final updated = zero.copyWith(
          isValid: !invalidated,
          calculatorResult: zero.calculatorResult!.copyWith(
            carbs: 13,
            totalInsulin: 24.2,
          ),
        );
        refresh.complete([zero, actual]);
        harness.dispatchEvent(TreatmentAvailableEvent<BolusWizard>(updated));
        if (invalidated) {
          await waitingAgain.future.timeout(const Duration(seconds: 5));
          expect(confirmed, isNull);
        } else {
          await waiting.timeout(const Duration(seconds: 5));
          expect(confirmed!.wizard, updated);
          expect(confirmed!.deliveredInsulin, 3);
        }
        expect(
          container.read(calculatorSubmissionsProvider).single.wizard,
          updated,
        );
      },
    );
  }
}
