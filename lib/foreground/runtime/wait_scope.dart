import 'dart:async';

import 'wait_handle.dart';

class WaitScope {
  final Set<WaitHandle<dynamic>> _handles = {};

  WaitHandle<T> track<T>(WaitHandle<T> handle) {
    _handles.add(handle);
    return handle;
  }

  Future<void> dispose() async {
    if (_handles.isEmpty) return;

    for (final handle in _handles.toList().reversed) {
      try {
        await handle.cancel();
      } catch (_) {
        // ignore cleanup errors
      }
    }

    _handles.clear();
  }
}