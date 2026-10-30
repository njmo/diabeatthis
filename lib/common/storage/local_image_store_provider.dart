import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_image_store.dart';

final localImageStoreProvider = Provider<LocalImageStore>(
  (ref) => const LocalImageStore(),
);
