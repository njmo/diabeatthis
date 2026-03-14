import 'dart:async';

import '../event/model/foreground_event.dart';
import '../task/base/task_context.dart';
import '../task/base/workflow_task.dart';
import 'task_cancellation.dart';
import 'task_cancelled_exception.dart';

class _EventWaiter<T extends ForegroundEvent> {
  final Type eventType;
  final bool Function(T event)? predicate;
  final Completer<T> completer;

  _EventWaiter({
    required this.eventType,
    required this.predicate,
    required this.completer,
  });
}

class _SignalWaiter {
  final String signalKey;
  final Completer<void> completer;

  _SignalWaiter({
    required this.signalKey,
    required this.completer,
  });
}

class WorkflowScheduler {
  final List<_EventWaiter<dynamic>> _eventWaiters = [];
  final List<_SignalWaiter> _signalWaiters = [];
  final List<TaskCancellation> _cancellations = [];
  final List<Future<void>> _taskFutures = [];

  bool _isDisposed = false;

  late final TaskContext _baseContext;

  WorkflowScheduler({
    required List<WorkflowTask> tasks,
  }) {
    _baseContext = TaskContext(
      cancellation: TaskCancellation(),
      waitForEvent: _waitForEventInternal,
      waitForSignal: _waitForSignalInternal,
      emitEvent: emitEvent,
      emitSignal: emitSignal,
    );

    for (final task in tasks) {
      _startTask(task);
    }
  }

  void _startTask(WorkflowTask task) {
    final cancellation = TaskCancellation();
    _cancellations.add(cancellation);

    final context = TaskContext(
      cancellation: cancellation,
      waitForEvent: _waitForEventInternal,
      waitForSignal: _waitForSignalInternal,
      emitEvent: emitEvent,
      emitSignal: emitSignal,
    );

    final future = task.run(context).catchError((error, stackTrace) {
      if (error is TaskCancelledException) {
        context.log('Task ${task.name} cancelled');
        return;
      }

      context.log('Task ${task.name} failed: $error\n$stackTrace');
    });

    _taskFutures.add(future);
  }

  Future<T> _waitForEventInternal<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    if (_isDisposed) {
      return Future<T>.error(const TaskCancelledException());
    }

    final completer = Completer<T>();
    final waiter = _EventWaiter<T>(
      eventType: T,
      predicate: predicate,
      completer: completer,
    );

    _eventWaiters.add(waiter);
    return completer.future;
  }

  Future<void> _waitForSignalInternal(String signalKey) {
    if (_isDisposed) {
      return Future<void>.error(const TaskCancelledException());
    }

    final completer = Completer<void>();
    final waiter = _SignalWaiter(
      signalKey: signalKey,
      completer: completer,
    );

    _signalWaiters.add(waiter);
    return completer.future;
  }

  Future<void> emitEvent(ForegroundEvent event) async {
    if (_isDisposed) return;

    final waiters = List<_EventWaiter<dynamic>>.from(_eventWaiters);

    for (final waiter in waiters) {
      if (event.runtimeType != waiter.eventType) continue;

      final predicate = waiter.predicate;
      final typedEvent = event;

      if (predicate != null && !predicate(typedEvent)) {
        continue;
      }

      if (!waiter.completer.isCompleted) {
        waiter.completer.complete(typedEvent);
      }
      _eventWaiters.remove(waiter);
    }
  }

  Future<void> emitSignal(String signalKey) async {
    if (_isDisposed) return;

    final waiters = List<_SignalWaiter>.from(_signalWaiters);

    for (final waiter in waiters) {
      if (waiter.signalKey != signalKey) continue;

      if (!waiter.completer.isCompleted) {
        waiter.completer.complete();
      }
      _signalWaiters.remove(waiter);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final cancellation in _cancellations) {
      cancellation.cancel();
    }

    for (final waiter in _eventWaiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(const TaskCancelledException());
      }
    }
    _eventWaiters.clear();

    for (final waiter in _signalWaiters) {
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(const TaskCancelledException());
      }
    }
    _signalWaiters.clear();

    await Future.wait(_taskFutures, eagerError: false);
  }
}