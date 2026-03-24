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

typedef EventWaitFactory =
    WaitHandle<T> Function<T extends ForegroundEvent>({
      bool Function(T event)? predicate,
    });

typedef SignalWaitFactory = WaitHandle<void> Function(String signalKey);

class RuntimeContext with Logging {
  final TaskCancellation cancellation;
  final TaskInterruptController interruptController;
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;
  final EventWaitFactory _eventWaitFactory;
  final SignalWaitFactory _signalWaitFactory;
  final ProviderContainer container;

  RuntimeContext({
    required this.cancellation,
    required this.interruptController,
    required this.emitEvent,
    required this.emitSignal,
    required EventWaitFactory eventWaitFactory,
    required SignalWaitFactory signalWaitFactory,
    required this.container,
  }) : _eventWaitFactory = eventWaitFactory,
       _signalWaitFactory = signalWaitFactory;

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
      container: container,
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
      return await interruptController.race(handle.future);
    } finally {
      await handle.cancel();
    }
  }

  Future<T> waitForEventWithTimeout<T extends ForegroundEvent>(
    Duration duration, {
    bool Function(T event)? predicate,
  }) {
    return eventWait<T>(predicate: predicate).timeout(duration).future;
  }

  Future<T?> waitForEventWithTimeoutOrNull<T extends ForegroundEvent>(
    Duration duration, {
    bool Function(T event)? predicate,
  }) {
    return eventWait<T>(predicate: predicate).timeoutOrNull(duration).future;
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

    final future = Future.any<void>([
      Future.delayed(duration),
      cancellation.onCancel.then((_) => throw const TaskCancelledException()),
    ]);

    return WaitHandle.fromFuture(future);
  }

  Future<void> waitUntil(DateTime at) {
    final now = clock.now();
    final delay = at.isAfter(now) ? at.difference(now) : Duration.zero;
    return waitForDuration(delay);
  }

  WaitHandle<T> futureWait<T>(Future<T> future) {
    return WaitHandle.fromFuture(future);
  }

  Future<T> any<T>(Iterable<WaitHandle<T>> waits) async {
    cancellation.throwIfCancelled();

    final handles = waits.toList();
    try {
      return await interruptController.race(
        Future.any(handles.map((h) => h.future)),
      );
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
      return await body(scoped);
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

  ScopedRuntimeContext({required RuntimeContext base, required WaitScope scope})
    : _base = base,
      _scope = scope,
      super(
        cancellation: base.cancellation,
        interruptController: base.interruptController,
        emitEvent: base.emitEvent,
        emitSignal: base.emitSignal,
        eventWaitFactory: base._eventWaitFactory,
        signalWaitFactory: base._signalWaitFactory,
        container: base.container,
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
  WaitHandle<T> futureWait<T>(Future<T> future) {
    return _scope.track(_base.futureWait(future));
  }

  @override
  Future<T> any<T>(Iterable<WaitHandle<T>> waits) {
    return _base.any(waits);
  }
}
