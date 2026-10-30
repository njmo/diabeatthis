import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Portable paths relative to application support; separate from bundled assets.
class LocalImageStore {
  const LocalImageStore({this.directory = getApplicationSupportDirectory});

  final Future<Directory> Function() directory;

  static bool contains(String? path) =>
      path != null &&
      RegExp(r'^local-images/[a-z0-9_-]+/[a-zA-Z0-9_-]+\.png$').hasMatch(path);

  Future<File> resolve(String path) async {
    if (!contains(path)) {
      throw ArgumentError.value(path, 'path', 'Invalid local image path');
    }
    return File('${(await directory()).path}/$path');
  }

  Future<({File file, String path})> savePng(Uint8List bytes) async {
    final path =
        'local-images/generated/icon-${DateTime.now().microsecondsSinceEpoch}.png';
    final file = await resolve(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return (file: file, path: path);
  }
}
