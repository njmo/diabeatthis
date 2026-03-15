import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../event/model/foreground_event.dart';
import '../task/base/runtime_context.dart';
import '../task/base/workflow_task.dart';
import 'runtime_input.dart';
import 'runtime_waiter.dart';
import 'task_cancellation.dart';
import 'task_cancelled_exception.dart';
import 'wait_handle.dart';

class WorkflowScheduler {
  final List<RuntimeWaiter> _waiters = [];
  final List<TaskCancellation> _cancellations = [];
  final List<Future<void>> _taskFutures = [];
  final Queue<RuntimeInput> _pendingInputs = Queue<RuntimeInput>();

  bool _isDisposed = false;
  bool _flushScheduled = false;

  void startTask(WorkflowTask task, RuntimeContext context) {
    final future = task.run(context).catchError((error, stackTrace) {
      if (error is TaskCancelledException) {
        context.log('Task ${task.name} cancelled');
        return;
      }

      context.log('Task ${task.name} failed: $error\n$stackTrace');
    });

    _taskFutures.add(future);
  }

  RuntimeContext buildRuntimeContext(ProviderContainer container) {
    final cancellation = TaskCancellation();
    _cancellations.add(cancellation);

    return RuntimeContext(
      cancellation: cancellation,
      emitEvent: emitEvent,
      emitSignal: emitSignal,
      eventWaitFactory: _createEventWaitHandle,
      signalWaitFactory: _createSignalWaitHandle,
      container: container,
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
      cancel: () {
        waiter.cancel(const TaskCancelledException(), StackTrace.current);
      },
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
      cancel: () {
        waiter.cancel(const TaskCancelledException(), StackTrace.current);
      },
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

    for (final cancellation in _cancellations) {
      cancellation.cancel();
    }

    final error = const TaskCancelledException();
    final stack = StackTrace.current;

    for (final waiter in List<RuntimeWaiter>.from(_waiters)) {
      waiter.cancel(error, stack);
    }

    _waiters.clear();
    _pendingInputs.clear();

    await Future.wait(_taskFutures, eagerError: false);
  }

  void debugPrintState() {
    print('--- WORKFLOW SCHEDULER ---');
    print('waiters: ${_waiters.length}');
    print('pendingInputs: ${_pendingInputs.length}');
    print('taskFutures: ${_taskFutures.length}');
    print('disposed: $_isDisposed');
    print('flushScheduled: $_flushScheduled');
    print('--------------------------');
  }
}