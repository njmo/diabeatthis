import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const profilePhotoFileKey = 'profile-photo-file';

class ProfilePhotoStore {
  const ProfilePhotoStore(this.preferences, this.directory);

  final SharedPreferences preferences;
  final Directory directory;

  static Future<ProfilePhotoStore> create(SharedPreferences preferences) async {
    final documents = await getApplicationDocumentsDirectory();
    return ProfilePhotoStore(
      preferences,
      Directory('${documents.path}/profile'),
    );
  }

  Future<String?> load() async {
    final filename = preferences.getString(profilePhotoFileKey);
    if (filename == null) return null;
    final file = File('${directory.path}/$filename');
    return await file.exists() ? file.path : null;
  }

  Future<String> save(Uint8List bytes) async {
    final photo = await compute(prepareProfilePhoto, bytes);
    await directory.create(recursive: true);
    final previous = await load();
    final filename = 'avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final file = File('${directory.path}/$filename');
    try {
      await file.writeAsBytes(photo, flush: true);
      if (!await preferences.setString(profilePhotoFileKey, filename)) {
        throw const FileSystemException(
          'Could not save profile photo preference.',
        );
      }
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await deletePrevious(previous);
    return file.path;
  }

  Future<void> remove() async {
    final previous = await load();
    if (!await preferences.remove(profilePhotoFileKey)) {
      throw const FileSystemException(
        'Could not remove profile photo preference.',
      );
    }
    await deletePrevious(previous);
  }

  Future<void> deletePrevious(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup must not hide an already successful preference update.
    }
  }
}

Uint8List prepareProfilePhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Cannot decode profile photo.');
  }
  final oriented = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(oriented, size: 512);
  return Uint8List.fromList(img.encodeJpg(square, quality: 85));
}
