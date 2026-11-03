import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_photo_source.dart';
import 'profile_photo_store_provider.dart';

final changeProfilePhotoUseCaseProvider = Provider<ChangeProfilePhotoUseCase>(
  ChangeProfilePhotoUseCase.new,
);

class ChangeProfilePhotoUseCase {
  const ChangeProfilePhotoUseCase(this._ref);

  final Ref _ref;

  Future<String?> choose() async {
    final bytes = await _ref.read(profilePhotoSourceProvider).pick();
    if (bytes == null || !_ref.mounted) return null;
    return save(bytes);
  }

  Future<String> save(Uint8List bytes) async {
    final store = await _ref.read(profilePhotoStoreProvider.future);
    return store.save(bytes);
  }

  Future<void> remove() async {
    final store = await _ref.read(profilePhotoStoreProvider.future);
    await store.remove();
  }
}
