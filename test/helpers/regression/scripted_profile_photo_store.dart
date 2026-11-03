import 'dart:typed_data';

import 'package:diabeatthis/common/profile/profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedProfilePhotoStore extends Fake implements ProfilePhotoStore {
  final ScriptedRead<String?> loads;
  final ScriptedRead<String> saves;
  final ScriptedRead<void> removals;
  ScriptedProfilePhotoStore({
    required this.loads,
    required this.saves,
    required this.removals,
  });
  @override
  Future<String?> load() => loads([]);
  @override
  Future<String> save(Uint8List bytes) => saves([bytes]);
  @override
  Future<void> remove() => removals([]);
}
