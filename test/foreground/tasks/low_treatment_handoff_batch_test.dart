import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
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
  test('retains the complete live batch through the next recovery tick', () {
    fakeAsync((async) {
      final start = DateTime(2026, 9, 28, 12);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final useCase = BatchRecordingHandoff();
        final container = ProviderContainer(
          overrides: [
            lowTreatmentHandoffUseCaseProvider.overrideWithValue(useCase),
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
        final first = Treat(externalId: 'one', createdAt: start, carbs: 10);
        final second = Treat(
          externalId: 'two',
          createdAt: start.add(const Duration(seconds: 1)),
          carbs: 10,
        );
        harness.dispatchEvent(TreatmentAvailableEvent<Treat>(first));
        harness.dispatchEvent(TreatmentAvailableEvent<Treat>(second));
        async.flushMicrotasks();
        expect(useCase.batches.last, [first, second]);
        expect(useCase.batches.where((batch) => batch.length == 1), isEmpty);
        async.elapse(const Duration(minutes: 1));
        harness.dispatchTick(start.add(async.elapsed));
        async.flushMicrotasks();
        expect(useCase.batches.last, [first, second]);
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    });
  });
}

class BatchRecordingHandoff extends Fake implements LowTreatmentHandoffUseCase {
  final batches = <List<Treatment>>[];
  @override
  Future<List<LowTreatmentHandoffMatch>> reconcile({
    required DateTime now,
    List<Treatment> liveTreatments = const [],
  }) async {
    batches.add(List.of(liveTreatments));
    return [];
  }
}
