import 'dart:async';

import 'local_image_store.dart';

/// Owns newly selected local images until they are persisted or discarded.
class LocalImageEditSession {
  LocalImageEditSession({required this.store, required this.isInUse});

  final LocalImageStore store;
  final Future<bool> Function(String path) isInUse;
  final Set<String> _paths = {};
  Future<void>? _pendingWrite;
  bool _closed = false;

  void track(String path) {
    if (!LocalImageStore.contains(path)) return;
    _paths.add(path);
    // A picker can finish after its editor has already been closed.
    if (_closed) unawaited(cleanup());
  }

  Future<void> save(Future<void> Function() write) async {
    final completed = Completer<void>();
    _pendingWrite = completed.future;
    try {
      await write();
    } finally {
      completed.complete();
    }
  }

  Future<void> discard() {
    _closed = true;
    return cleanup();
  }

  Future<void> cleanup() async {
    // Closing a route during a save must not delete the file before commit.
    await _pendingWrite;
    for (final path in _paths.toList()) {
      try {
        if (!await isInUse(path)) {
          final file = await store.resolve(path);
          if (await file.exists()) await file.delete();
        }
        _paths.remove(path);
      } catch (_) {
        // If storage cannot be checked, preserve the image rather than risk
        // deleting a saved image. Cleanup must not break canceling or saving.
      }
    }
  }
}
