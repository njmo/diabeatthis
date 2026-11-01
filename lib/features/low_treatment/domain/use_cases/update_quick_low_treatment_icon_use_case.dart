import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/storage/local_image_edit_session.dart';
import '../../../../common/storage/local_image_store.dart';
import '../../../../common/storage/local_image_store_provider.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../ingredients/data/icons/food_icon_assets.dart';

final updateQuickLowTreatmentIconUseCaseProvider = Provider(
  (ref) => UpdateQuickLowTreatmentIconUseCase(
    ref.watch(databaseProvider),
    ref.watch(localImageStoreProvider),
  ),
);

class UpdateQuickLowTreatmentIconUseCase {
  const UpdateQuickLowTreatmentIconUseCase(this.db, this.store);

  final DatabaseImpl db;
  final LocalImageStore store;

  LocalImageEditSession _session(String path) => LocalImageEditSession(
    store: store,
    isInUse: (path) async =>
        await (db.select(db.ingredient)
              ..where((row) => row.iconAssetPath.equals(path))
              ..limit(1))
            .getSingleOrNull() !=
        null,
  )..track(path);

  Future<void> call({required int ingredientId, required String path}) async {
    if (!FoodIconAssets.contains(path) && !LocalImageStore.contains(path)) {
      throw ArgumentError.value(path, 'path', 'Invalid ingredient icon');
    }
    final images = _session(path);
    try {
      await images.save(() async {
        final count =
            await (db.update(db.ingredient)
                  ..where((row) => row.id.equals(ingredientId)))
                .write(IngredientCompanion(iconAssetPath: Value(path)));
        if (count != 1) throw StateError('Ingredient not found');
      });
    } finally {
      await images.discard();
    }
  }

  Future<void> discard(String path) => _session(path).discard();
}
