import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'change_profile_photo_use_case.dart';
import 'profile_photo_store.dart';
import 'profile_photo_store_provider.dart';

export 'profile_photo_store_provider.dart' show profilePhotoStoreProvider;

final profilePhotoControllerProvider =
    AsyncNotifierProvider<ProfilePhotoController, String?>(
      ProfilePhotoController.new,
    );

class ProfilePhotoController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final preferences = await ref.watch(sharedPrefsProvider.future);
    if (preferences.getString(profilePhotoFileKey) == null) return null;
    final store = await ref.watch(profilePhotoStoreProvider.future);
    return store.load();
  }

  Future<void> choose() {
    final previousPath = state.value;
    return _update(() async {
      final path = await ref.read(changeProfilePhotoUseCaseProvider).choose();
      return path ?? previousPath;
    });
  }

  Future<void> save(Uint8List bytes) =>
      _update(() => ref.read(changeProfilePhotoUseCaseProvider).save(bytes));

  Future<void> remove() => _update(() async {
    await ref.read(changeProfilePhotoUseCaseProvider).remove();
    return null;
  });

  Future<void> _update(Future<String?> Function() operation) async {
    if (state.isLoading) return;
    final previous = state;
    state = const AsyncLoading<String?>();
    try {
      final path = await operation();
      if (ref.mounted) state = AsyncData(path);
    } catch (_) {
      if (ref.mounted) state = previous;
      rethrow;
    }
  }
}
