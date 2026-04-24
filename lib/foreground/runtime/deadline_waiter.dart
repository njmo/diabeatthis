import 'dart:async';

import 'runtime_input.dart';
import 'runtime_waiter.dart';

class DeadlineWaiter extends RuntimeWaiter {
  final DateTime deadline;
  final Completer<void> completer;
  final void Function(RuntimeWaiter waiter) onDone;

  DeadlineWaiter({
    required this.deadline,
    required this.completer,
    required this.onDone,
  });

  @override
  bool get isCompleted => completer.isCompleted;

  @override
  bool matches(RuntimeInput input) {
    if (input is! RuntimeTickInput) return false;
    return input.now.isAfter(deadline) || input.now.isAtSameMomentAs(deadline);
  }

  @override
  void complete(RuntimeInput input) {
    if (!completer.isCompleted) {
      completer.complete();
      onDone(this);
    }
  }

  @override
  void cancel(Object error, StackTrace stackTrace) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
      onDone(this);
    }
  }
}