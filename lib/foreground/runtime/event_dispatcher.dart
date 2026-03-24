import 'dart:collection';

import '../../core/logger/logger.dart';
import '../event/model/foreground_event.dart';

class EventDispatcher with Logging {
  final Queue<ForegroundEvent> _queue = Queue<ForegroundEvent>();

  void dispatch(ForegroundEvent event) {
    logI('Dispatching event ${event.runtimeType}');
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