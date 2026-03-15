import 'dart:async';

import '../event/model/foreground_event.dart';
import 'runtime_input.dart';

abstract class RuntimeWaiter {
  bool get isCompleted;

  bool matches(RuntimeInput input);

  void complete(RuntimeInput input);

  void cancel(Object error, StackTrace stackTrace);
}

class EventWaiter<T extends ForegroundEvent> extends RuntimeWaiter {
  final Type eventType;
  final bool Function(T event)? predicate;
  final Completer<T> completer;
  final void Function(RuntimeWaiter waiter) onDone;

  EventWaiter({
    required this.eventType,
    required this.predicate,
    required this.completer,
    required this.onDone,
  });

  @override
  bool get isCompleted => completer.isCompleted;

  @override
  bool matches(RuntimeInput input) {
    if (input is! RuntimeEventInput) return false;

    final event = input.event;
    if (event.runtimeType != eventType) return false;

    final typedEvent = event as T;
    if (predicate != null && !predicate!(typedEvent)) return false;

    return true;
  }

  @override
  void complete(RuntimeInput input) {
    if (input is! RuntimeEventInput) return;
    if (completer.isCompleted) return;

    completer.complete(input.event as T);
    onDone(this);
  }

  @override
  void cancel(Object error, StackTrace stackTrace) {
    if (completer.isCompleted) return;

    completer.completeError(error, stackTrace);
    onDone(this);
  }
}

class SignalWaiter extends RuntimeWaiter {
  final String signalKey;
  final Completer<void> completer;
  final void Function(RuntimeWaiter waiter) onDone;

  SignalWaiter({
    required this.signalKey,
    required this.completer,
    required this.onDone,
  });

  @override
  bool get isCompleted => completer.isCompleted;

  @override
  bool matches(RuntimeInput input) {
    return input is RuntimeSignalInput && input.signalKey == signalKey;
  }

  @override
  void complete(RuntimeInput input) {
    if (completer.isCompleted) return;

    completer.complete();
    onDone(this);
  }

  @override
  void cancel(Object error, StackTrace stackTrace) {
    if (completer.isCompleted) return;

    completer.completeError(error, stackTrace);
    onDone(this);
  }
}