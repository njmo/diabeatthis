import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/logger/logger.dart';

/// Keeps notification navigation pending until the application's UI is ready.
class DeferredUiAction<T extends Object> with Logging {
  final BuildContext? Function() getContext;
  final Future<void> Function(BuildContext context, T value) open;
  T? _pending;
  T? _openValue;
  Timer? _retry;
  bool _scheduled = false;
  bool _disposed = false;
  int _attempts = 0;

  DeferredUiAction({required this.getContext, required this.open});

  void request(T value) {
    if (_disposed || _openValue == value) return;
    _pending = value;
    _attempts = 0;
    _schedule();
  }

  void retryPending() {
    _attempts = 0;
    _schedule();
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _retry?.cancel();
    _retry = null;
  }

  void _schedule() {
    if (_disposed || _pending == null || _scheduled || _openValue != null) {
      return;
    }
    _retry?.cancel();
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || _pending == null || _openValue != null) return;
      final context = getContext();
      if (context == null || !context.mounted) {
        if (++_attempts < 50) {
          _retry = Timer(const Duration(milliseconds: 100), _schedule);
        }
        return;
      }
      final value = _pending!;
      _pending = null;
      _openValue = value;
      unawaited(_open(context, value));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open(BuildContext context, T value) async {
    try {
      await open(context, value);
    } catch (error, stackTrace) {
      logE(
        'Could not open pending action',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _openValue = null;
      _schedule();
    }
  }
}
