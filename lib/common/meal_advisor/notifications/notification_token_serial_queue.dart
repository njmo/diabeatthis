import 'dart:async';

/// Serializes token invalidation and registration across runtime replacements.
class NotificationTokenSerialQueue {
  Future<void> _tail = Future.value();
  int _invalidation = 0;
  int _completedInvalidation = 0;

  void invalidate() => _invalidation++;

  Future<void> run({
    required Future<void> Function() deleteToken,
    required Future<void> Function() operation,
  }) {
    final completion = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        while (_completedInvalidation != _invalidation) {
          final current = _invalidation;
          await deleteToken();
          _completedInvalidation = current;
        }
        await operation();
        completion.complete();
      } catch (error, stack) {
        completion.completeError(error, stack);
      }
    });
    return completion.future;
  }
}
