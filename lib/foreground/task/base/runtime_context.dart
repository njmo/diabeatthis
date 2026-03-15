import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../event/model/foreground_event.dart';
import '../../runtime/task_cancellation.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../../runtime/wait_handle.dart';

typedef EmitEventFn = void Function(ForegroundEvent event);
typedef EmitSignalFn = void Function(String signalKey);

typedef EventWaitFactory = WaitHandle<T> Function<T extends ForegroundEvent>({
bool Function(T event)? predicate,
});

typedef SignalWaitFactory = WaitHandle<void> Function(String signalKey);

class RuntimeContext {
  final TaskCancellation cancellation;
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;
  final EventWaitFactory _eventWaitFactory;
  final SignalWaitFactory _signalWaitFactory;
  final ProviderContainer container;

  RuntimeContext({
    required this.cancellation,
    required this.emitEvent,
    required this.emitSignal,
    required EventWaitFactory eventWaitFactory,
    required SignalWaitFactory signalWaitFactory,
    required this.container,
  })  : _eventWaitFactory = eventWaitFactory,
        _signalWaitFactory = signalWaitFactory;

  bool get isCancelled => cancellation.isCancelled;

  void throwIfCancelled() {
    cancellation.throwIfCancelled();
  }

  Future<T> waitForEvent<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    return eventWait<T>(predicate: predicate).future;
  }

  WaitHandle<T> eventWait<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    cancellation.throwIfCancelled();
    return _eventWaitFactory<T>(predicate: predicate);
  }

  Future<void> waitForSignal(String signalKey) {
    return signalWait(signalKey).future;
  }

  WaitHandle<void> signalWait(String signalKey) {
    cancellation.throwIfCancelled();
    return _signalWaitFactory(signalKey);
  }

  Future<void> waitForDuration(Duration duration) {
    return durationWait(duration).future;
  }

  WaitHandle<void> durationWait(Duration duration) {
    cancellation.throwIfCancelled();

    final future = Future.any<void>([
      Future.delayed(duration),
      cancellation.onCancel.then((_) => throw const TaskCancelledException()),
    ]);

    return WaitHandle<void>(
      future: future,
      cancel: () {},
    );
  }

  Future<void> waitUntil(DateTime at) {
    return untilWait(at).future;
  }

  WaitHandle<void> untilWait(DateTime at) {
    final now = DateTime.now();
    final delay = at.isAfter(now) ? at.difference(now) : Duration.zero;
    return durationWait(delay);
  }

  Future<T> any<T>(Iterable<Object> waitsOrFutures) async {
    cancellation.throwIfCancelled();

    final handles = waitsOrFutures.map((item) {
      if (item is WaitHandle<T>) {
        return item;
      }

      if (item is Future<T>) {
        return WaitHandle<T>(
          future: item,
          cancel: () {},
        );
      }

      throw ArgumentError(
        'Expected WaitHandle<$T> or Future<$T>, got ${item.runtimeType}',
      );
    }).toList();

    try {
      return await Future.any(handles.map((h) => h.future));
    } finally {
      for (final handle in handles) {
        await handle.cancel();
      }
    }
  }

  void log(String message) {
    print('[RuntimeContext] $message');
  }
}