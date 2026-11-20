import 'dart:async';

import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/foreground/runtime/foreground_runtime_disposer.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/runtime/workflow_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/controlled_collector.dart';
import '../utils/controlled_meal_monitor.dart';

void main() {
  LogRuntimeConfig.configure(isUnitTest: true, enableBuffer: false);

  test('shutdown can cancel a wait before its caller subscribes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final scheduler = WorkflowScheduler();
    final context = scheduler.createContext(container);
    final waits = [
      context.signalWait('work').future,
      context.durationWait(const Duration(hours: 1)).future,
      context
          .wallClockWaitUntilHandle(
            DateTime.now().add(const Duration(hours: 1)),
          )
          .future,
    ];

    await scheduler.dispose();
    await Future<void>.delayed(Duration.zero);

    for (final wait in waits) {
      await expectLater(wait, throwsA(isA<TaskCancelledException>()));
    }
  });

  test('scheduler bounds shutdown even when task I/O ignores cancellation', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      final scheduler = WorkflowScheduler();
      final blocked = Completer<void>();
      scheduler.startTask(
        ControlledMealMonitor((_) => blocked.future),
        scheduler.createContext(container),
      );
      var stopped = false;
      unawaited(scheduler.dispose().then((_) => stopped = true));
      async.flushMicrotasks();
      expect(stopped, isFalse);
      async.elapse(WorkflowScheduler.shutdownTimeout);
      expect(stopped, isTrue);
      blocked.completeError(StateError('Late I/O error'));
      async.flushMicrotasks();
      container.dispose();
    });
  });

  test('blocked collector cannot prevent provider disposal', () {
    fakeAsync((async) {
      var released = false;
      final resource = Provider((ref) {
        ref.onDispose(() => released = true);
        return 1;
      });
      final container = ProviderContainer();
      container.read(resource);
      final blocked = Completer<void>();
      final collector = ControlledCollector(() => blocked.future);
      var stopped = false;
      unawaited(
        ForegroundRuntimeDisposer()
            .dispose(
              scheduler: WorkflowScheduler(),
              collectors: [collector],
              container: container,
            )
            .then((_) => stopped = true),
      );
      async.flushMicrotasks();
      expect(collector.stopped, isTrue);
      expect(released, isFalse);
      async.elapse(WorkflowScheduler.shutdownTimeout);
      expect(stopped, isTrue);
      expect(released, isTrue);
      blocked.completeError(StateError('Late collector error'));
      async.flushMicrotasks();
    });
  });

  test('collector disposal error still releases providers', () async {
    var released = false;
    final resource = Provider((ref) {
      ref.onDispose(() => released = true);
      return 1;
    });
    final container = ProviderContainer();
    container.read(resource);
    await expectLater(
      ForegroundRuntimeDisposer().dispose(
        scheduler: WorkflowScheduler(),
        collectors: [
          ControlledCollector(() => throw StateError('Dispose failed')),
        ],
        container: container,
      ),
      throwsStateError,
    );
    expect(released, isTrue);
  });
}
