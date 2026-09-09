import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../event/model/foreground_event.dart';
import '../task/base/runtime_context.dart';
import '../task/base/workflow_task.dart';
import 'deadline_waiter.dart';
import 'event_inbox.dart';
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
  static const shutdownTimeout = Duration(seconds: 2);

  final List<RuntimeWaiter> _waiters = [];
  final List<EventInbox<ForegroundEvent>> _inboxes = [];
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
      eventInboxFactory: openEventInbox,
      signalWaitFactory: _createSignalWaitHandle,
      deadlineWaitFactory: createDeadlineWaitHandle,
      container: container,
      tick: tick,
    );
  }

  EventInbox<T> openEventInbox<T extends ForegroundEvent>() {
    if (_isDisposed) throw const TaskCancelledException();
    late final EventInbox<T> inbox;
    inbox = EventInbox<T>(onClose: () => _inboxes.remove(inbox));
    _inboxes.add(inbox);
    return inbox;
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
    if (_isDisposed) throw const TaskCancelledException();
    final taskRuntime = context.overrideControllers(
      cancellation: TaskCancellation(),
      interruptController: TaskInterruptController(),
    );
    final future = _runTask(task, taskRuntime);

    _taskRuntimes.add(
      _TaskRuntime(
        task: task,
        cancellation: taskRuntime.cancellation,
        interruptController: taskRuntime.interruptController,
        future: future,
      ),
    );
  }

  Future<void> _runTask(WorkflowTask task, RuntimeContext context) async {
    try {
      await task.run(context);
    } catch (error, stackTrace) {
      if (!context.isCancelled) {
        logE('Task ${task.name} failed: $error\n$stackTrace');
      }
    } finally {
      if (!context.isCancelled) {
        final event = task.unexpectedStopEvent;
        if (event != null) emitEvent(event);
      }
      context.cancellation.cancel();
    }
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

  void tick(DateTime now) {
    if (_isDisposed) return;
    _pendingInputs.addLast(RuntimeTickInput(now));
    _ensureFlushScheduled();
  }

  WaitHandle<void> createDeadlineWaitHandle(DateTime deadline) {
    if (_isDisposed) {
      return WaitHandle<void>(
        future: Future.error(const TaskCancelledException()),
        cancel: () {},
      );
    }

    final completer = Completer<void>();
    late final DeadlineWaiter waiter;

    waiter = DeadlineWaiter(
      deadline: deadline,
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
      for (final inbox in List<EventInbox<ForegroundEvent>>.of(_inboxes)) {
        inbox.add(event);
      }

      for (final runtime in _taskRuntimes.where(
        (r) => r.task.interruptable && !r.cancellation.isCancelled,
      )) {
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
    for (final inbox in List<EventInbox<ForegroundEvent>>.of(_inboxes)) {
      inbox.close();
    }

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

    // Foreign I/O futures cannot always be cancelled. Do not let them block
    // service teardown; their eventual failures remain observed by _runTask.
    await Future.wait(
      _taskRuntimes.map((r) => r.future),
      eagerError: false,
    ).timeout(
      shutdownTimeout,
      onTimeout: () {
        logW('Timed out waiting for foreground tasks to stop');
        return <void>[];
      },
    );
  }
}
