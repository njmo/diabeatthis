import 'dart:async';

typedef WaitCancel = FutureOr<void> Function();

class WaitHandle<T> {
  final Future<T> future;
  final WaitCancel _cancel;

  const WaitHandle({
    required this.future,
    required WaitCancel cancel,
  }) : _cancel = cancel;

  Future<void> cancel() async {
    await _cancel();
  }

  WaitHandle<R> map<R>(FutureOr<R> Function(T value) mapper) {
    return WaitHandle<R>(
      future: future.then(mapper),
      cancel: cancel,
    );
  }
}