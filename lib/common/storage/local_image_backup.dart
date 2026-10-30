import 'dart:convert';
import 'dart:typed_data';

import 'local_image_store.dart';

class LocalImageBackup {
  const LocalImageBackup(this.store);

  final LocalImageStore store;

  Future<Map<String, String>> exportImages(Iterable<String> paths) async {
    final images = <String, String>{};
    for (final path in paths.toSet().where(LocalImageStore.contains)) {
      final file = await store.resolve(path);
      if (await file.exists()) {
        images[path] = base64Encode(await file.readAsBytes());
      }
    }
    return images;
  }

  Future<Map<String, String>> restoreImages(Object? payload) async {
    if (payload == null) return {};
    if (payload is! Map) throw const FormatException('Invalid image backup');
    final decoded = <String, Uint8List>{};
    for (final entry in payload.entries) {
      if (entry.key is! String ||
          !LocalImageStore.contains(entry.key as String) ||
          entry.value is! String) {
        throw const FormatException('Invalid image backup path');
      }
      final bytes = base64Decode(entry.value as String);
      const signature = [137, 80, 78, 71, 13, 10, 26, 10];
      if (bytes.length < signature.length ||
          List.generate(
            signature.length,
            (i) => bytes[i] == signature[i],
          ).contains(false)) {
        throw const FormatException('Invalid PNG backup');
      }
      decoded[entry.key as String] = bytes;
    }
    final restored = <String, String>{};
    try {
      for (final entry in decoded.entries) {
        final saved = await store.savePng(entry.value);
        restored[entry.key] = saved.path;
      }
      return restored;
    } catch (_) {
      await removeImages(restored.values);
      rethrow;
    }
  }

  Future<void> removeImages(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        final file = await store.resolve(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup must not hide a failed database restore.
      }
    }
  }
}
