import 'dart:async';

import '../event/model/foreground_event.dart';
import 'task_interrupted_exception.dart';

class TaskInterruptController {
  Completer<ForegroundEvent>? _interruptCompleter;

  TaskInterruptController() {
    _interruptCompleter = Completer<ForegroundEvent>();
  }

  Future<ForegroundEvent> get onInterrupt => _interruptCompleter!.future;

  void interrupt(ForegroundEvent event) {
    if (_interruptCompleter != null && !_interruptCompleter!.isCompleted) {
      _interruptCompleter!.complete(event);
    }
  }

  void reset() {
    if (_interruptCompleter == null || _interruptCompleter!.isCompleted) {
      _interruptCompleter = Completer<ForegroundEvent>();
    }
  }

  Future<T> race<T>(Future<T> future) async {
    final result = await Future.any<Object?>([
      future,
      onInterrupt.then((event) => TaskInterruptedException(event)),
    ]);

    if (result is TaskInterruptedException) {
      throw result;
    }

    return result as T;
  }
}