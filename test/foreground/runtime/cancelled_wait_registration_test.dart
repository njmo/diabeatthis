import 'package:clock/clock.dart';
import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

class CancelledRegistrationEvent extends ForegroundEvent {
  const CancelledRegistrationEvent();
}

void main() {
  test(
    'cancellation before race construction observes mapped event errors',
    () async {
      final harness = FakeRuntimeHarness();
      addTearDown(harness.dispose);

      final result = harness.runtimeContext.withWaitScope<void>((scope) async {
        final response = scope.eventWait<CancelledRegistrationEvent>();
        harness.cancellation.cancel();
        await scope.any<void>([
          response.map<void>((_) {}),
          scope.wallClockWaitUntilHandle(
            clock.now().add(const Duration(days: 1)),
          ),
        ]);
      });

      await expectLater(result, throwsA(isA<TaskCancelledException>()));
      await Future<void>.delayed(Duration.zero);
      expect(harness.activeWaitersCount, 0);
    },
  );

  test(
    'an already cancelled race still cancels and observes its handles',
    () async {
      final harness = FakeRuntimeHarness();
      addTearDown(harness.dispose);
      final handle = harness.runtimeContext.signalWait('changed');
      harness.cancellation.cancel();

      await expectLater(
        harness.runtimeContext.any<void>([handle]),
        throwsA(isA<TaskCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(harness.activeWaitersCount, 0);
      await expectLater(handle.future, throwsA(isA<TaskCancelledException>()));
    },
  );
}
