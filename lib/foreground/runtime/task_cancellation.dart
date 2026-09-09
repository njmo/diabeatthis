import 'dart:async';

import 'task_cancelled_exception.dart';

class TaskCancellation {
  bool _isCancelled = false;
  final Completer<void> _onCancelCompleter = Completer<void>();

  bool get isCancelled => _isCancelled;

  Future<void> get onCancel => _onCancelCompleter.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;

    if (!_onCancelCompleter.isCompleted) {
      _onCancelCompleter.complete();
    }
  }

  Future<T> bind<T>(Future<T> operation) async {
    throwIfCancelled();
    final result = await Future.any<T>([
      operation,
      onCancel.then<T>((_) => throw const TaskCancelledException()),
    ]);
    throwIfCancelled();
    return result;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const TaskCancelledException();
    }
  }
}
