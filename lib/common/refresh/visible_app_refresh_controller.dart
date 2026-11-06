import 'dart:async';

/// Polls only while explicitly active and ignores results from a stopped session.
class VisibleAppRefreshController<T> {
  VisibleAppRefreshController({
    required this.fetch,
    required this.onData,
    required this.onError,
    this.onStarted,
    this.interval = const Duration(seconds: 30),
  });
  final Future<T> Function() fetch;
  final void Function(T) onData;
  final void Function(Object) onError;
  final void Function()? onStarted;
  final Duration interval;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _timer;
  Future<void>? _running;

  void start() {
    if (_active || _disposed) return;
    _active = true;
    _generation++;
    unawaited(refreshNow());
  }

  void stop() {
    _active = false;
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refreshNow() {
    if (!_active || _disposed) return Future.value();
    if (_running != null) return _running!;
    _timer?.cancel();
    final generation = _generation;
    onStarted?.call();
    return _running = _refresh(generation).whenComplete(() {
      _running = null;
      if (!_active || _disposed) return;
      if (generation != _generation) {
        unawaited(refreshNow());
      } else {
        _timer = Timer(interval, () => unawaited(refreshNow()));
      }
    });
  }

  Future<void> _refresh(int generation) async {
    try {
      final result = await fetch();
      if (_active && !_disposed && generation == _generation) onData(result);
    } catch (error) {
      if (_active && !_disposed && generation == _generation) onError(error);
    }
  }

  void dispose() {
    stop();
    _disposed = true;
  }
}
