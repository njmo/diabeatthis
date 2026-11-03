import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profilePhotoSourceProvider = Provider<ProfilePhotoSource>((ref) {
  return const ProfilePhotoSource();
});

class ProfilePhotoSource {
  const ProfilePhotoSource();

  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    final path = file.path;
    if (path == null) {
      throw const FileSystemException('Selected photo has no readable path.');
    }
    return File(path).readAsBytes();
  }
}
