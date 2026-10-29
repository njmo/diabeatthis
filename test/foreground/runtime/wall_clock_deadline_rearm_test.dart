import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test('early timer wake rearms until the actual wall-clock deadline', () {
    fakeAsync((async) {
      var now = DateTime.utc(2026, 10, 29, 12);
      final deadline = now.add(const Duration(milliseconds: 10));
      withClock(Clock(() => now), () {
        final harness = FakeRuntimeHarness();
        var completed = false;
        final handle = harness.runtimeContext.wallClockWaitUntilHandle(
          deadline,
        );
        unawaited(handle.future.then((_) => completed = true));
        now = deadline.subtract(const Duration(microseconds: 500));
        async.elapse(const Duration(milliseconds: 10));
        expect(completed, isFalse);
        expect(harness.activeWaitersCount, 1);
        expect(harness.emittedTicks, isEmpty);
        expect(async.nonPeriodicTimerCount, 1);
        now = deadline;
        async.elapse(const Duration(milliseconds: 1));
        expect(completed, isTrue);
        expect(harness.emittedTicks, [deadline]);
        expect(harness.activeWaitersCount, 0);
        expect(async.nonPeriodicTimerCount, 0);
        unawaited(harness.dispose());
        async.flushMicrotasks();
      });
    });
  });

  test(
    'cancellation after an early wake also cancels the replacement timer',
    () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 10, 29, 12);
        final deadline = now.add(const Duration(milliseconds: 10));
        withClock(Clock(() => now), () {
          final harness = FakeRuntimeHarness();
          final handle = harness.runtimeContext.wallClockWaitUntilHandle(
            deadline,
          );
          Object? failure;
          unawaited(
            handle.future.catchError((Object error) {
              failure = error;
            }),
          );
          now = deadline.subtract(const Duration(microseconds: 500));
          async.elapse(const Duration(milliseconds: 10));
          unawaited(handle.cancel());
          async.flushMicrotasks();
          expect(failure, isA<TaskCancelledException>());
          expect(harness.activeWaitersCount, 0);
          expect(async.nonPeriodicTimerCount, 0);
          now = deadline.add(const Duration(days: 1));
          async.elapse(const Duration(days: 1));
          expect(harness.emittedTicks, isEmpty);
          unawaited(harness.dispose());
          async.flushMicrotasks();
        });
      });
    },
  );

  test('an external deadline tick cancels a pending wall-clock timer', () {
    fakeAsync((async) {
      final now = DateTime.utc(2026, 10, 29, 12);
      final deadline = now.add(const Duration(seconds: 1));
      withClock(Clock.fixed(now), () {
        final harness = FakeRuntimeHarness();
        var completed = false;
        final handle = harness.runtimeContext.wallClockWaitUntilHandle(
          deadline,
        );
        unawaited(handle.future.then((_) => completed = true));
        harness.dispatchTick(deadline);
        async.flushMicrotasks();
        expect(completed, isTrue);
        expect(harness.activeWaitersCount, 0);
        expect(async.nonPeriodicTimerCount, 0);
        async.elapse(const Duration(seconds: 2));
        expect(harness.emittedTicks, isEmpty);
        unawaited(harness.dispose());
        async.flushMicrotasks();
      });
    });
  });

  test('moving the wall clock backwards preserves the original deadline', () {
    fakeAsync((async) {
      var now = DateTime.utc(2026, 10, 29, 12);
      final deadline = now.add(const Duration(seconds: 1));
      withClock(Clock(() => now), () {
        final harness = FakeRuntimeHarness();
        var completed = false;
        final handle = harness.runtimeContext.wallClockWaitUntilHandle(
          deadline,
        );
        unawaited(handle.future.then((_) => completed = true));
        now = now.subtract(const Duration(hours: 1));
        async.elapse(const Duration(seconds: 1));
        expect(completed, isFalse);
        expect(harness.emittedTicks, isEmpty);
        now = deadline;
        async.elapse(const Duration(hours: 1, seconds: 1));
        expect(completed, isTrue);
        expect(harness.activeWaitersCount, 0);
        expect(harness.emittedTicks, [deadline]);
        expect(async.nonPeriodicTimerCount, 0);
        unawaited(harness.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
