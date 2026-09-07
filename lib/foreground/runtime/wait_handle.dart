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
    return WaitHandle<R>(future: future.then(mapper), cancel: cancel);
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

  static WaitHandle<T> fromFuture<T>(Future<T> future) {
    return WaitHandle<T>(future: future, cancel: () {});
  }
}
