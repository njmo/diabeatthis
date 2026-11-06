import 'dart:async';

import 'package:flutter/foundation.dart';

/// Lets a surrounding step submit a mounted form without owning its draft.
class FormSubmissionController extends ChangeNotifier {
  Future<bool> Function()? _action;
  bool _ready = false;
  bool _disposed = false;
  bool get isAttached => _action != null;
  bool get isReady => _ready;

  void attach(Future<bool> Function() action, {required bool ready}) {
    if (_disposed) return;
    _action = action;
    _setReady(ready);
  }

  void detach(Future<bool> Function() action) {
    if (_disposed || !identical(_action, action)) return;
    _action = null;
    _setReady(false);
  }

  void _setReady(bool value) {
    if (_ready == value) return;
    _ready = value;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<bool> submit() async =>
      !_disposed && _ready && _action != null ? await _action!() : false;

  @override
  void dispose() {
    _disposed = true;
    _action = null;
    super.dispose();
  }
}
