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

  void throwIfCancelled() {
    if (_isCancelled) {
      throw const TaskCancelledException();
    }
  }
}