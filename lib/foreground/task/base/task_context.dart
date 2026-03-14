import 'dart:async';

import '../../event/model/foreground_event.dart';
import '../../runtime/task_cancellation.dart';
import '../../runtime/task_cancelled_exception.dart';

typedef WaitForEventFn = Future<T> Function<T extends ForegroundEvent>({
bool Function(T event)? predicate,
});

typedef WaitForSignalFn = Future<void> Function(String signalKey);
typedef EmitEventFn = Future<void> Function(ForegroundEvent event);
typedef EmitSignalFn = Future<void> Function(String signalKey);

class TaskContext {
  final TaskCancellation cancellation;
  final WaitForEventFn _waitForEvent;
  final WaitForSignalFn _waitForSignal;
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;

  TaskContext({
    required this.cancellation,
    required WaitForEventFn waitForEvent,
    required WaitForSignalFn waitForSignal,
    required this.emitEvent,
    required this.emitSignal,
  })  : _waitForEvent = waitForEvent,
        _waitForSignal = waitForSignal;

  bool get isCancelled => cancellation.isCancelled;

  void throwIfCancelled() {
    cancellation.throwIfCancelled();
  }

  Future<T> waitForEvent<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) async {
    cancellation.throwIfCancelled();

    final result = await Future.any<Object?>([
      _waitForEvent<T>(predicate: predicate),
      cancellation.onCancel.then((_) => const TaskCancelledException()),
    ]);

    if (result is TaskCancelledException) {
      throw const TaskCancelledException();
    }

    return result as T;
  }

  Future<void> waitForSignal(String signalKey) async {
    cancellation.throwIfCancelled();

    final result = await Future.any<Object?>([
      _waitForSignal(signalKey),
      cancellation.onCancel.then((_) => const TaskCancelledException()),
    ]);

    if (result is TaskCancelledException) {
      throw const TaskCancelledException();
    }
  }

  Future<void> waitForDuration(Duration duration) async {
    cancellation.throwIfCancelled();

    final result = await Future.any<Object?>([
      Future.delayed(duration),
      cancellation.onCancel.then((_) => const TaskCancelledException()),
    ]);

    if (result is TaskCancelledException) {
      throw const TaskCancelledException();
    }
  }

  Future<void> waitUntil(DateTime at) async {
    final now = DateTime.now();
    final delay = at.isAfter(now) ? at.difference(now) : Duration.zero;
    await waitForDuration(delay);
  }

  Future<T> race<T>(Iterable<Future<T>> futures) async {
    cancellation.throwIfCancelled();

    final result = await Future.any<Object?>([
      ...futures,
      cancellation.onCancel.then((_) => const TaskCancelledException()),
    ]);

    if (result is TaskCancelledException) {
      throw const TaskCancelledException();
    }

    return result as T;
  }

  void log(String message) {
    print('[TaskContext] $message');
  }
}