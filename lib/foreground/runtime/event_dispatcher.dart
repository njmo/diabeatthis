import 'dart:collection';

import '../event/model/foreground_event.dart';

class EventDispatcher {
  final Queue<ForegroundEvent> _queue = Queue<ForegroundEvent>();

  void dispatch(ForegroundEvent event) {
    _queue.addLast(event);
  }

  bool get hasPendingEvents => _queue.isNotEmpty;

  ForegroundEvent? tryDequeue() {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }

  List<ForegroundEvent> drainAll() {
    final result = <ForegroundEvent>[];
    while (_queue.isNotEmpty) {
      result.add(_queue.removeFirst());
    }
    return result;
  }
}