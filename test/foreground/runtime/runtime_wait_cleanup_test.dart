import 'package:clock/clock.dart';
import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/runtime/task_interrupted_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/fake_runtime_harness.dart';

class CleanupInterruptEvent extends ForegroundEvent {
  const CleanupInterruptEvent();
}

void main() {
  late FakeRuntimeHarness harness;
  setUp(() => harness = FakeRuntimeHarness());
  tearDown(() => harness.dispose());

  test(
    'cancelling a duration handle immediately removes its scheduler waiter',
    () async {
      final handle = harness.runtimeContext.durationWait(
        const Duration(days: 1),
      );
      final result = expectLater(
        handle.future,
        throwsA(isA<TaskCancelledException>()),
      );
      expect(harness.activeWaitersCount, 1);
      await handle.cancel();
      await result;
      expect(harness.activeWaitersCount, 0);
    },
  );

  test(
    'each signal winner cleans up all losing waits across repeated iterations',
    () async {
      for (var iteration = 0; iteration < 25; iteration++) {
        final result = harness.runtimeContext.withWaitScope(
          (scope) => scope.any<void>([
            scope.signalWait('changed'),
            scope.eventWait<CleanupInterruptEvent>().map<void>((_) {}),
            scope.wallClockWaitUntilHandle(
              clock.now().add(const Duration(days: 1)),
            ),
          ]),
        );
        expect(harness.activeWaitersCount, 3);
        harness.dispatchSignal('changed');
        await result;
        expect(harness.activeWaitersCount, 0);
      }
      expect(harness.emittedTicks, isEmpty);
    },
  );

  test(
    'scope cleans waits when reconciliation fails before the race',
    () async {
      await expectLater(
        harness.runtimeContext.withWaitScope<void>((scope) async {
          scope.signalWait('changed').future.ignore();
          scope
              .wallClockWaitUntilHandle(
                clock.now().add(const Duration(days: 1)),
              )
              .future
              .ignore();
          throw StateError('Reconciliation failed');
        }),
        throwsStateError,
      );
      expect(harness.activeWaitersCount, 0);
    },
  );

  test('interrupt cleans every losing waiter', () async {
    final result = harness.runtimeContext.withWaitScope(
      (scope) => scope.any<void>([
        scope.signalWait('changed'),
        scope.wallClockWaitUntilHandle(
          clock.now().add(const Duration(days: 1)),
        ),
      ]),
    );
    final checked = expectLater(
      result,
      throwsA(isA<TaskInterruptedException>()),
    );
    harness.interruptWith(const CleanupInterruptEvent());
    await checked;
    expect(harness.activeWaitersCount, 0);
  });

  test('task cancellation cleans signal and wall-clock waits', () async {
    final result = harness.runtimeContext.withWaitScope(
      (scope) => scope.any<void>([
        scope.signalWait('changed'),
        scope.wallClockWaitUntilHandle(
          clock.now().add(const Duration(days: 1)),
        ),
      ]),
    );
    final checked = expectLater(result, throwsA(isA<TaskCancelledException>()));
    harness.cancellation.cancel();
    await checked;
    expect(harness.activeWaitersCount, 0);
  });

  test(
    'wall-clock deadline wakes without external data and removes the waiter',
    () async {
      final handle = harness.runtimeContext.wallClockWaitUntilHandle(
        clock.now().add(const Duration(milliseconds: 10)),
      );
      await handle.future.timeout(const Duration(seconds: 2));
      expect(harness.emittedTicks, hasLength(1));
      expect(harness.activeWaitersCount, 0);
    },
  );

  test('cancelling a wall-clock wait cancels its timer too', () async {
    final handle = harness.runtimeContext.wallClockWaitUntilHandle(
      clock.now().add(const Duration(milliseconds: 10)),
    );
    final checked = expectLater(
      handle.future,
      throwsA(isA<TaskCancelledException>()),
    );
    await handle.cancel();
    await checked;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.activeWaitersCount, 0);
    expect(harness.emittedTicks, isEmpty);
  });
}
