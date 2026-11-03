import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/features/low_treatment/application/process_low_treatment_uploads_use_case.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_upload_provider.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/low_treatment_upload_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test('upload queue wakes without AAPS ticks and cancels all waits', () {
    fakeAsync((async) {
      final start = DateTime.utc(2026, 11, 3);
      withClock(Clock(() => start.add(async.elapsed)), () {
        final worker = RecordingUploadWorker();
        final container = ProviderContainer(
          overrides: [
            processLowTreatmentUploadsUseCaseProvider.overrideWithValue(worker),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        unawaited(
          const LowTreatmentUploadTask().run(harness.runtimeContext).catchError(
            (Object error) {
              if (error is! TaskCancelledException) throw error;
            },
          ),
        );
        async.flushMicrotasks();
        expect(worker.calls, 1);
        async.elapse(const Duration(seconds: 15));
        expect(worker.calls, 2);
        harness.cancel();
        async.flushMicrotasks();
        expect(harness.activeWaitersCount, 0);
        expect(async.nonPeriodicTimerCount, 0);
        container.dispose();
      });
    });
  });
}

class RecordingUploadWorker extends Fake
    implements ProcessLowTreatmentUploadsUseCase {
  int calls = 0;
  @override
  Future<void> call(DateTime now) async {
    calls++;
  }
}
