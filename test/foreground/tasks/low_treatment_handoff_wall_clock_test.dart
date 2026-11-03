import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/handoff/handoff_gateway.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_aaps_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_handoff_match.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/low_treatment_handoff_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'confirms settled carbs after 11 seconds without another AAPS event or tick',
    () {
      fakeAsync((async) {
        final start = DateTime.utc(2026, 11, 3, 14, 45, 35);
        withClock(Clock(() => start.add(async.elapsed)), () {
          final gateway = WallClockCarbGateway();
          final useCase = SettlingCarbHandoff();
          final container = ProviderContainer(
            overrides: [
              lowTreatmentHandoffUseCaseProvider.overrideWithValue(useCase),
              lowTreatmentPipControllerProvider.overrideWithValue(
                HandoffController(gateway),
              ),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          unawaited(
            const LowTreatmentHandoffTask()
                .run(harness.runtimeContext)
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                }),
          );
          async.flushMicrotasks();
          harness.dispatchEvent(
            TreatmentAvailableEvent<Treat>(
              Treat(externalId: 'receipt-79', createdAt: start, carbs: 11),
            ),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 10));
          expect(gateway.confirmations, isEmpty);
          async.elapse(const Duration(seconds: 1));
          expect(gateway.confirmations, ['lowTreatment:313']);
          expect(useCase.completed, isTrue);
          harness.cancel();
          async.flushMicrotasks();
          expect(async.nonPeriodicTimerCount, 0);
          expect(harness.activeWaitersCount, 0);
          container.dispose();
        });
      });
    },
  );
}

class WallClockCarbGateway extends Fake implements HandoffGateway {
  final confirmations = <String>[];
  @override
  bool get isSupported => true;
  @override
  Future<void> updateRows(String sessionId, List<bool> completed) async {
    expect(completed, [true]);
    confirmations.add(sessionId);
  }
}

class SettlingCarbHandoff extends Fake implements LowTreatmentHandoffUseCase {
  bool completed = false;
  @override
  Future<List<LowTreatmentHandoffMatch>> reconcile({
    required DateTime now,
    List<Treatment> liveTreatments = const [],
  }) async {
    if (completed || liveTreatments.isEmpty) return [];
    final at = liveTreatments.single.createdAt!;
    if (!now.isAfter(at.add(const Duration(seconds: 10)))) return [];
    return [
      LowTreatmentHandoffMatch(
        mealId: 313,
        suggestionAt: null,
        treatAt: at,
        treatExternalId: 'receipt-79',
      ),
    ];
  }

  @override
  Future<void> markCompleted(int mealId) async {
    completed = true;
  }
}
