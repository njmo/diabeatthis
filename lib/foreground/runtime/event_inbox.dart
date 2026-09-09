import 'dart:async';
import 'dart:collection';

import '../event/model/foreground_event.dart';
import 'task_cancelled_exception.dart';

/// A single-consumer subscription. Events remain queued between reads.
class EventInbox<T extends ForegroundEvent> {
  EventInbox({required this._onClose});
  final void Function() _onClose;
  final Queue<T> _pending = Queue<T>();
  Completer<void>? _wake;
  bool _closed = false;
  bool _reading = false;

  void add(ForegroundEvent event) {
    if (_closed || event is! T) return;
    _pending.addLast(event);
    _wake?.complete();
    _wake = null;
  }

  List<T> drain() {
    if (_closed) throw const TaskCancelledException();
    final result = _pending.toList();
    _pending.clear();
    return result;
  }

  Future<List<T>> nextBatch() async {
    if (_reading) throw StateError('EventInbox supports one consumer');
    _reading = true;
    try {
      if (_closed) throw const TaskCancelledException();
      if (_pending.isEmpty) {
        _wake = Completer<void>();
        await _wake!.future;
      }
      return drain();
    } finally {
      _reading = false;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _pending.clear();
    _wake?.complete();
    _wake = null;
    _onClose();
  }
}
