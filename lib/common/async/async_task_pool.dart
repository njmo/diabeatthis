import 'dart:async';
import 'dart:collection';

/// Bounds concurrent I/O while releasing slots after failures too.
class AsyncTaskPool {
  final int limit;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  AsyncTaskPool(this.limit) : assert(limit > 0);

  Future<T> run<T>(Future<T> Function() task) async {
    if (_active >= limit) {
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _active++;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _active--;
      }
    }
  }
}
