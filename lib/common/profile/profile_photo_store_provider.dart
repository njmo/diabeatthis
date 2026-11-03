import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'profile_photo_store.dart';

final profilePhotoStoreProvider = FutureProvider<ProfilePhotoStore>((
  ref,
) async {
  final preferences = await ref.watch(sharedPrefsProvider.future);
  return ProfilePhotoStore.create(preferences);
});
