import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger.dart';
import '../../event/model/foreground_event.dart';
import '../../runtime/task_cancellation.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../../runtime/task_interrupt_controller.dart';
import '../../runtime/wait_handle.dart';
import '../../runtime/wait_scope.dart';

typedef EmitEventFn = void Function(ForegroundEvent event);
typedef EmitSignalFn = void Function(String signalKey);
typedef DeadlineWaitFn = WaitHandle<void> Function(DateTime deadline);
typedef TickFn = void Function(DateTime now);

typedef EventWaitFactory =
    WaitHandle<T> Function<T extends ForegroundEvent>({
      bool Function(T event)? predicate,
    });

typedef SignalWaitFactory = WaitHandle<void> Function(String signalKey);

class RuntimeContext with Logging {
  static int _waitSeq = 0;

  final TaskCancellation cancellation;
  final TaskInterruptController interruptController;
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;
  final EventWaitFactory _eventWaitFactory;
  final SignalWaitFactory _signalWaitFactory;
  final ProviderContainer container;
  final DeadlineWaitFn _deadlineWaitFactory;
  final TickFn tick;

  RuntimeContext({
    required this.cancellation,
    required this.interruptController,
    required this.emitEvent,
    required this.emitSignal,
    required this.tick,
    required this._eventWaitFactory,
    required this._signalWaitFactory,
    required this._deadlineWaitFactory,
    required this.container,
  });

  RuntimeContext overrideControllers({
    TaskCancellation? cancellation,
    TaskInterruptController? interruptController,
  }) {
    return RuntimeContext(
      cancellation: cancellation ?? this.cancellation,
      interruptController: interruptController ?? this.interruptController,
      emitEvent: emitEvent,
      emitSignal: emitSignal,
      eventWaitFactory: _eventWaitFactory,
      signalWaitFactory: _signalWaitFactory,
      deadlineWaitFactory: _deadlineWaitFactory,
      container: container,
      tick: tick,
    );
  }

  bool get isCancelled => cancellation.isCancelled;

  void throwIfCancelled() {
    cancellation.throwIfCancelled();
  }

  Future<T> waitForEvent<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) async {
    cancellation.throwIfCancelled();

    final handle = eventWait<T>(predicate: predicate);

    try {
      final result = await interruptController.race(handle.future);
      return result;
    } finally {
      await handle.cancel();
    }
  }

  Future<T> waitForEventWithTimeout<T extends ForegroundEvent>(
    Duration duration, {
    bool Function(T event)? predicate,
  }) async {
    cancellation.throwIfCancelled();

    final eventHandle = eventWait<T>(predicate: predicate);
    final timeoutHandle = durationWait(duration);

    try {
      final result = await interruptController.race(
        eventHandle.timeout(duration, timeoutHandle).future,
      );
      return result;
    } finally {
      await eventHandle.cancel();
      await timeoutHandle.cancel();
    }
  }

  Future<T?> waitForEventWithTimeoutOrNull<T extends ForegroundEvent>(
    Duration duration, {
    bool Function(T event)? predicate,
  }) async {
    try {
      final result = await waitForEventWithTimeout<T>(
        duration,
        predicate: predicate,
      );
      return result;
    } on TimeoutException {
      return null;
    } on WaitTimeoutException {
      return null;
    }
  }

  WaitHandle<T> eventWait<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    cancellation.throwIfCancelled();
    return _eventWaitFactory<T>(predicate: predicate);
  }

  Future<void> waitForSignal(String signalKey) async {
    cancellation.throwIfCancelled();

    final handle = signalWait(signalKey);

    try {
      await interruptController.race(handle.future);
    } finally {
      await handle.cancel();
    }
  }

  WaitHandle<void> signalWait(String signalKey) {
    cancellation.throwIfCancelled();
    return _signalWaitFactory(signalKey);
  }

  Future<void> waitForDuration(Duration duration) async {
    cancellation.throwIfCancelled();

    final handle = durationWait(duration);

    try {
      await interruptController.race(handle.future);
    } finally {
      await handle.cancel();
    }
  }

  WaitHandle<void> durationWait(Duration duration) {
    cancellation.throwIfCancelled();

    final normalized = duration.isNegative ? Duration.zero : duration;
    final deadline = clock.now().add(normalized);

    return _waitUntilHandle(deadline);
  }

  Future<void> waitUntil(DateTime at) async {
    cancellation.throwIfCancelled();

    final handle = waitUntilHandle(at);

    try {
      await interruptController.race(handle.future);
    } finally {
      await handle.cancel();
    }
  }

  WaitHandle<void> waitUntilHandle(DateTime at) {
    cancellation.throwIfCancelled();

    return _waitUntilHandle(at);
  }

  WaitHandle<void> _waitUntilHandle(DateTime deadline) {
    final waitId = ++_waitSeq;

    final deadlineHandle = _deadlineWaitFactory(deadline);

    final completer = Completer<void>();

    var finished = false;
    Future<void>? cancelDeadlineFuture;

    Future<void> finish(
      String source, [
      Object? error,
      StackTrace? stackTrace,
    ]) async {
      if (finished) {
        return;
      }

      finished = true;

      cancelDeadlineFuture ??= deadlineHandle.cancel();
      try {
        await cancelDeadlineFuture;
      } catch (e, st) {
        logE(
          "[RuntimeContext] wait#$waitId deadlineHandle.cancel() failed: $e\n$st",
        );
      }

      if (completer.isCompleted) {
        return;
      }

      if (error != null) {
        completer.completeError(error, stackTrace);
      } else {
        completer.complete();
      }
    }

    deadlineHandle.future
        .then((_) {
          unawaited(finish('deadline_handle'));
        })
        .catchError((Object e, StackTrace st) {
          unawaited(finish('deadline_handle_error', e, st));
        });

    cancellation.onCancel.then((_) {
      unawaited(finish('cancellation', const TaskCancelledException()));
    });

    return WaitHandle.fromFuture(completer.future);
  }

  WaitHandle<T> futureWait<T>(Future<T> future) {
    return WaitHandle.fromFuture(future);
  }

  Future<T> any<T>(Iterable<WaitHandle<T>> waits) async {
    cancellation.throwIfCancelled();

    final handles = waits.toList();

    try {
      final result = await interruptController.race(
        Future.any(handles.map((h) => h.future)),
      );
      return result;
    } finally {
      for (final handle in handles) {
        await handle.cancel();
      }
    }
  }

  Future<T> withWaitScope<T>(
    Future<T> Function(RuntimeContext context) body,
  ) async {
    final scope = WaitScope();

    try {
      final scoped = ScopedRuntimeContext(base: this, scope: scope);
      final result = await body(scoped);
      return result;
    } finally {
      await scope.dispose();
    }
  }

  void log(String message) {
    logI('[RuntimeContext] $message');
  }
}

class ScopedRuntimeContext extends RuntimeContext {
  final RuntimeContext _base;
  final WaitScope _scope;

  ScopedRuntimeContext({required RuntimeContext base, required this._scope})
    : _base = base,
      super(
        cancellation: base.cancellation,
        interruptController: base.interruptController,
        emitEvent: base.emitEvent,
        emitSignal: base.emitSignal,
        eventWaitFactory: base._eventWaitFactory,
        signalWaitFactory: base._signalWaitFactory,
        deadlineWaitFactory: base._deadlineWaitFactory,
        container: base.container,
        tick: base.tick,
      );

  @override
  WaitHandle<T> eventWait<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    return _scope.track(_base.eventWait<T>(predicate: predicate));
  }

  @override
  WaitHandle<void> signalWait(String signalKey) {
    return _scope.track(_base.signalWait(signalKey));
  }

  @override
  WaitHandle<void> durationWait(Duration duration) {
    return _scope.track(_base.durationWait(duration));
  }

  @override
  WaitHandle<void> waitUntilHandle(DateTime at) {
    return _scope.track(_base.waitUntilHandle(at));
  }

  @override
  WaitHandle<T> futureWait<T>(Future<T> future) {
    return _scope.track(_base.futureWait(future));
  }

  @override
  Future<T> any<T>(Iterable<WaitHandle<T>> waits) {
    return _base.any(waits);
  }
}
