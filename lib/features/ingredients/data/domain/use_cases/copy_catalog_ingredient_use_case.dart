import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/ingredient_catalog/catalog_ingredient.dart';
import '../../../../../common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import '../../../../../common/ingredient_catalog/ingredient_identity.dart';
import '../../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';

final copyCatalogIngredientUseCaseProvider =
    Provider<CopyCatalogIngredientUseCase>(
      (ref) => CopyCatalogIngredientUseCase(ref.watch(databaseProvider)),
    );

class CopyCatalogIngredientUseCase {
  const CopyCatalogIngredientUseCase(this.db);
  final DatabaseImpl db;
  Future<int> call(int localIngredientId) => db.transaction(() async {
    final origin = await db
        .customSelect(
          'SELECT * FROM ingredient_origin WHERE ingredient_id = ?',
          variables: [Variable(localIngredientId)],
        )
        .getSingle();
    if (origin.read<String>('source') != 'firebase') {
      throw StateError('Ingredient is not a catalog mirror');
    }
    final ingredient = await db.ingredientDao.getIngredientById(
      localIngredientId,
    );
    return DriftSelectedCatalogIngredientStore(db).copyAsLocal(
      CatalogIngredient(
        identity: IngredientIdentity(
          source: IngredientSource.firebase,
          sourceId: origin.read<String>('source_id'),
        ),
        name: ingredient.name,
        englishName: origin.read<String>('english_name'),
        languageCode: origin.read<String>('display_language_code'),
        revision: origin.read<String>('source_revision'),
        carbsPer100g: ingredient.carbsPer100g,
        fiberPer100g: ingredient.fiberPer100g,
        fatPer100g: ingredient.fatPer100g,
        proteinPer100g: ingredient.proteinPer100g,
        carbsLabelMode: CarbsLabelModeX.fromStorage(ingredient.carbsLabelMode),
        iconAssetPath: ingredient.iconAssetPath,
      ),
      sourceSnapshotJson: origin.read<String>('source_snapshot_json'),
    );
  });
}
