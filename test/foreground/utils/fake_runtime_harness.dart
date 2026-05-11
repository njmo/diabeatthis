import 'dart:async';

import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/runtime/deadline_waiter.dart';
import 'package:diabeatthis/foreground/runtime/runtime_input.dart';
import 'package:diabeatthis/foreground/runtime/runtime_waiter.dart';
import 'package:diabeatthis/foreground/runtime/task_cancellation.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/runtime/task_interrupt_controller.dart';
import 'package:diabeatthis/foreground/runtime/wait_handle.dart';
import 'package:diabeatthis/foreground/task/base/runtime_context.dart';
import 'package:diabeatthis/foreground/task/base/workflow_task.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeRuntimeHarness {
  final ProviderContainer container;
  final TaskCancellation cancellation;
  final TaskInterruptController interruptController;

  final List<ForegroundEvent> emittedEvents = [];
  final List<String> emittedSignals = [];
  final List<String> logs = [];

  final List<RuntimeWaiter> _waiters = [];

  late final RuntimeContext runtimeContext;

  FakeRuntimeHarness({
    ProviderContainer? container,
    TaskCancellation? cancellation,
    TaskInterruptController? interruptController,
  }) : container = container ?? ProviderContainer(),
       cancellation = cancellation ?? TaskCancellation(),
       interruptController = interruptController ?? TaskInterruptController() {
    runtimeContext = RuntimeContext(
      cancellation: this.cancellation,
      interruptController: this.interruptController,
      emitEvent: _emitEvent,
      emitSignal: _emitSignal,
      eventWaitFactory: _createEventWaitHandle,
      signalWaitFactory: _createSignalWaitHandle,
      deadlineWaitFactory: _createDeadlineWaitHandle,
      container: this.container,
      tick: (DateTime now) {},
    );
  }

  void _emitEvent(ForegroundEvent event) {
    emittedEvents.add(event);
  }

  void _emitSignal(String signalKey) {
    emittedSignals.add(signalKey);
    _deliverInput(RuntimeSignalInput(signalKey));
  }

  void log(String message) {
    logs.add(message);
  }

  int get activeWaitersCount => _waiters.length;

  void debugPrintState() {
    debugPrint('--- FAKE RUNTIME HARNESS ---');
    debugPrint('waiters: ${_waiters.length}');
    debugPrint('cancelled: ${cancellation.isCancelled}');
    debugPrint('----------------------------');
  }

  WaitHandle<void> _createDeadlineWaitHandle(DateTime deadline) {
    if (cancellation.isCancelled) {
      return WaitHandle<void>(
        future: Future<void>.error(const TaskCancelledException()),
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
      cancel: () {
        waiter.cancel(const TaskCancelledException(), StackTrace.current);
      },
    );
  }

  void dispatchEvent(ForegroundEvent event) {
    _deliverInput(RuntimeEventInput(event));
  }

  void dispatchSignal(String signalKey) {
    _deliverInput(RuntimeSignalInput(signalKey));
  }

  void dispatchTick(DateTime now) {
    _deliverInput(RuntimeTickInput(now));
  }

  void dispatchEventToTask(
    InterruptableWorkflowTask task,
    ForegroundEvent event,
  ) {
    final shouldInterrupt = task.shouldInterrupt(event);

    if (shouldInterrupt) {
      interruptController.interrupt(event);
    }

    _deliverInput(RuntimeEventInput(event));
  }

  void interruptWith(ForegroundEvent event) {
    interruptController.interrupt(event);
  }

  void cancel() {
    cancellation.cancel();

    final error = const TaskCancelledException();
    final stack = StackTrace.current;

    for (final waiter in List<RuntimeWaiter>.from(_waiters)) {
      waiter.cancel(error, stack);
    }

    _waiters.clear();
  }

  WaitHandle<T> _createEventWaitHandle<T extends ForegroundEvent>({
    bool Function(T event)? predicate,
  }) {
    if (cancellation.isCancelled) {
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
    if (cancellation.isCancelled) {
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

  void _deliverInput(RuntimeInput input) {
    final snapshot = List<RuntimeWaiter>.from(_waiters);

    for (final waiter in snapshot) {
      if (waiter.isCompleted) continue;
      if (!waiter.matches(input)) continue;

      waiter.complete(input);
    }
  }

  Future<void> dispose() async {
    cancel();
    container.dispose();
  }
}
