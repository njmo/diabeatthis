import 'dart:async';

class WaitTimeoutException implements Exception {
  final Duration duration;

  const WaitTimeoutException(this.duration);

  @override
  String toString() => 'WaitTimeoutException(duration: $duration)';
}

typedef WaitCancel = FutureOr<void> Function();

class WaitHandle<T> {
  final Future<T> future;
  final WaitCancel _cancel;

  const WaitHandle({required this.future, required this._cancel});

  Future<void> cancel() async {
    await _cancel();
  }

  WaitHandle<R> map<R>(FutureOr<R> Function(T value) mapper) {
    final mapped = future.then(mapper);
    // A later wait factory can throw before a race subscribes to this handle.
    // Observing it here preserves errors for awaiters without leaking them.
    mapped.ignore();
    return WaitHandle<R>(future: mapped, cancel: cancel);
  }

  WaitHandle<T?> timeoutOrNull(
    Duration duration,
    WaitHandle<void> deadlineHandle,
  ) {
    late final Future<T?> timedFuture;

    timedFuture = Future.any([future, deadlineHandle.future.then((_) => null)]);

    return WaitHandle<T?>(
      future: () async {
        try {
          return await timedFuture;
        } finally {
          await cancel();
          await deadlineHandle.cancel();
        }
      }(),
      cancel: () async {
        await cancel();
        await deadlineHandle.cancel();
      },
    );
  }

  WaitHandle<T> timeout(Duration duration, WaitHandle<void> deadlineHandle) {
    late final Future<T> timedFuture;

    timedFuture = Future.any([
      future,
      deadlineHandle.future.then((_) => throw WaitTimeoutException(duration)),
    ]);

    return WaitHandle<T>(
      future: () async {
        try {
          return await timedFuture;
        } finally {
          await cancel();
          await deadlineHandle.cancel();
        }
      }(),
      cancel: () async {
        await cancel();
        await deadlineHandle.cancel();
      },
    );
  }

  /// A cancellable elapsed-time delay independent of periodic workflow ticks.
  static WaitHandle<void> delay(Duration duration) {
    final completion = Completer<void>();
    final timer = Timer(duration, completion.complete);
    return WaitHandle<void>(
      future: completion.future,
      cancel: () {
        timer.cancel();
        if (!completion.isCompleted) completion.complete();
      },
    );
  }

  static WaitHandle<T> fromFuture<T>(Future<T> future) {
    return WaitHandle<T>(future: future, cancel: () {});
  }
}
