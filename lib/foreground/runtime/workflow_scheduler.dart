import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../event/model/foreground_event.dart';
import '../task/base/runtime_context.dart';
import '../task/base/workflow_task.dart';
import 'runtime_input.dart';
import 'runtime_waiter.dart';
import 'task_cancellation.dart';
import 'task_cancelled_exception.dart';
import 'task_interrupt_controller.dart';
import 'wait_handle.dart';

class _TaskRuntime {
  final WorkflowTask task;
  final TaskCancellation cancellation;
  final TaskInterruptController interruptController;
  final Future<void> future;

  _TaskRuntime({
    required this.task,
    required this.cancellation,
    required this.interruptController,
    required this.future,
  });
}

class WorkflowScheduler with Logging {
  final List<RuntimeWaiter> _waiters = [];
  final List<_TaskRuntime> _taskRuntimes = [];
  final Queue<RuntimeInput> _pendingInputs = Queue<RuntimeInput>();

  bool _isDisposed = false;
  bool _flushScheduled = false;

  RuntimeContext createContext(ProviderContainer container) {
    final cancellation = TaskCancellation();
    final interruptController = TaskInterruptController();

    return RuntimeContext(
      cancellation: cancellation,
      interruptController: interruptController,
      emitEvent: emitEvent,
      emitSignal: emitSignal,
      eventWaitFactory: _createEventWaitHandle,
      signalWaitFactory: _createSignalWaitHandle,
      container: container,
    );
  }

  void debugPrintState() {
    logI('--- WORKFLOW SCHEDULER ---');
    logI('waiters: ${_waiters.length}');
    logI('pendingInputs: ${_pendingInputs.length}');
    logI('disposed: $_isDisposed');
    logI('flushScheduled: $_flushScheduled');
    logI('--------------------------');
  }

  void startTask(WorkflowTask task, RuntimeContext context) {
    final taskRuntime = context.overrideControllers(
      cancellation: TaskCancellation(),
      interruptController: TaskInterruptController(),
    );
    final future = task.run(taskRuntime).catchError((error, stackTrace) {
      if (error is TaskCancelledException) return;
      logE('Task ${task.name} failed: $error\n$stackTrace');
    });

    _taskRuntimes.add(
      _TaskRuntime(
        task: task,
        cancellation: taskRuntime.cancellation,
        interruptController: taskRuntime.interruptController,
        future: future,
      ),
    );
  }

  WaitHandle<T> _createEventWaitHandle<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    if (_isDisposed) {
      return WaitHandle<T>(
        future: Future<T>.error(const TaskCancelledException()),
        cancel: () {},
      );
    }

    final completer = Completer<T>();
    late final EventWaiter<T> waiter;

    waiter = EventWaiter<T>(
      eventType: T,
      predicate: predicate,
      completer: completer,
      onDone: _removeWaiter,
    );

    _waiters.add(waiter);

    return WaitHandle<T>(
      future: completer.future,
      cancel: () =>
          waiter.cancel(const TaskCancelledException(), StackTrace.current),
    );
  }

  WaitHandle<void> _createSignalWaitHandle(String signalKey) {
    if (_isDisposed) {
      return WaitHandle<void>(
        future: Future<void>.error(const TaskCancelledException()),
        cancel: () {},
      );
    }

    final completer = Completer<void>();
    late final SignalWaiter waiter;

    waiter = SignalWaiter(
      signalKey: signalKey,
      completer: completer,
      onDone: _removeWaiter,
    );

    _waiters.add(waiter);

    return WaitHandle<void>(
      future: completer.future,
      cancel: () =>
          waiter.cancel(const TaskCancelledException(), StackTrace.current),
    );
  }

  void _removeWaiter(RuntimeWaiter waiter) {
    _waiters.remove(waiter);
  }

  void emitEvent(ForegroundEvent event) {
    if (_isDisposed) return;
    _pendingInputs.addLast(RuntimeEventInput(event));
    _ensureFlushScheduled();
  }

  void emitSignal(String signalKey) {
    if (_isDisposed) return;
    _pendingInputs.addLast(RuntimeSignalInput(signalKey));
    _ensureFlushScheduled();
  }

  void _ensureFlushScheduled() {
    if (_flushScheduled) return;

    _flushScheduled = true;
    scheduleMicrotask(_flush);
  }

  void _flush() {
    _flushScheduled = false;

    while (_pendingInputs.isNotEmpty) {
      final input = _pendingInputs.removeFirst();
      _deliverInput(input);
    }
  }

  void _deliverInput(RuntimeInput input) {
    if (input is RuntimeEventInput) {
      final event = input.event;

      for (final runtime in _taskRuntimes.where((r) => r.task.interruptable)) {
        final interruptableTask = runtime.task as InterruptableWorkflowTask;
        final shouldInterrupt =
            interruptableTask.interruptableEventsMatcher.any(
              (matcher) => matcher(event),
            ) &&
            interruptableTask.shouldInterrupt(event);

        if (shouldInterrupt) {
          runtime.interruptController.interrupt(event);
        }
      }
    }

    final snapshot = List<RuntimeWaiter>.from(_waiters);

    for (final waiter in snapshot) {
      if (waiter.isCompleted) continue;
      if (!waiter.matches(input)) continue;

      waiter.complete(input);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final runtime in _taskRuntimes) {
      runtime.cancellation.cancel();
    }

    final error = const TaskCancelledException();
    final stack = StackTrace.current;

    for (final waiter in List<RuntimeWaiter>.from(_waiters)) {
      waiter.cancel(error, stack);
    }

    _waiters.clear();
    _pendingInputs.clear();

    await Future.wait(_taskRuntimes.map((r) => r.future), eagerError: false);
  }
}
