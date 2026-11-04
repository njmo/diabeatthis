import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../core/domain/model/carbs_label_mode.dart';
import '../../core/drift/database_impl.dart';
import 'catalog_ingredient.dart';
import 'ingredient_identity.dart';
import 'selected_catalog_ingredient_store.dart';

class DriftSelectedCatalogIngredientStore
    implements SelectedCatalogIngredientStore {
  const DriftSelectedCatalogIngredientStore(this.db);
  final DatabaseImpl db;

  @override
  Future<int?> findLocalId(IngredientIdentity identity) async {
    final row = await db
        .customSelect(
          'SELECT ingredient_id FROM ingredient_origin WHERE source = ? AND source_id = ?',
          variables: [
            Variable(identity.source.name),
            Variable(identity.sourceId),
          ],
        )
        .getSingleOrNull();
    return row?.read<int>('ingredient_id');
  }

  @override
  Future<int> mirror(CatalogIngredient ingredient) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await mirrorTransaction(ingredient);
      } on SqliteException catch (error) {
        // Roll back the temporary row before retrying a competing connection's
        // identity. Never resolve collisions by display name or barcode.
        if (attempt == 2 || !{19, 5, 6}.contains(error.resultCode)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
    throw StateError('Catalog mirror retry exhausted');
  }

  Future<int> mirrorTransaction(CatalogIngredient ingredient) => db.transaction(
    () async {
      validate(ingredient);
      // Acquire the writer lock with the conditional INSERT before reading
      // identity; deferred readers must not deadlock upgrading their locks.
      final id = await insertNutrition(ingredient, onlyIfIdentityMissing: true);
      if (id == 0) {
        final existing = await findLocalId(ingredient.identity);
        if (existing == null) throw StateError('Catalog identity disappeared');
        return existing;
      }
      await db.customUpdate(
        '''
UPDATE ingredient_origin SET source = 'firebase', source_id = ?, source_revision = ?,
 english_name = ?, display_language_code = ?, source_snapshot_json = ?, confidence_origin = 'unassessed', creation_method = 'catalog_mirror'
WHERE ingredient_id = ?
''',
        variables: [
          Variable(ingredient.identity.sourceId),
          Variable(ingredient.revision),
          Variable(ingredient.englishName),
          Variable(ingredient.languageCode),
          Variable(jsonEncode(snapshot(ingredient))),
          Variable(id),
        ],
      );
      return id;
    },
  );

  /// Creates a deliberately independent ingredient. No external identity is
  /// attached, so future catalog selections cannot replace or deduplicate it.
  Future<int> copyAsLocal(
    CatalogIngredient ingredient, {
    String? sourceSnapshotJson,
  }) => db.transaction(() async {
    validate(ingredient);
    final copiedFrom = sourceSnapshotJson ?? jsonEncode(snapshot(ingredient));
    final source = Map<String, dynamic>.from(jsonDecode(copiedFrom) as Map);
    if (IngredientIdentity.fromJson(
              Map<String, dynamic>.from(source['identity'] as Map),
            ) !=
            ingredient.identity ||
        source['revision'] != ingredient.revision) {
      throw ArgumentError(
        'Copy source does not match the selected catalog revision',
      );
    }
    final id = await insertNutrition(ingredient);
    await db.customUpdate(
      "UPDATE ingredient_origin SET confidence_origin = 'unassessed', creation_method = 'catalog_copy', copied_from_json = ? WHERE ingredient_id = ?",
      variables: [Variable(copiedFrom), Variable(id)],
    );
    return id;
  });

  Future<void> recordPhotoReferenceOrigin(
    int localIngredientId, {
    required String referenceScope,
    required Map<String, Object?> provenance,
    bool nutritionConfidenceAssessed = false,
  }) async {
    if (!{'component', 'whole_plate'}.contains(referenceScope)) {
      throw ArgumentError.value(referenceScope, 'referenceScope');
    }
    final changed = await db.customUpdate(
      """
UPDATE ingredient_origin SET creation_method = 'photo_reference', reference_scope = ?,
 provenance_json = ?, confidence_origin = ?
WHERE ingredient_id = ? AND source = 'local' AND creation_method = 'user'
""",
      variables: [
        Variable(referenceScope),
        Variable(jsonEncode(provenance)),
        Variable(nutritionConfidenceAssessed ? 'user_assessed' : 'unassessed'),
        Variable(localIngredientId),
      ],
    );
    if (changed != 1) {
      throw StateError(
        'Reference provenance requires an uninitialized local ingredient',
      );
    }
  }

  Future<int> insertNutrition(
    CatalogIngredient ingredient, {
    bool onlyIfIdentityMissing = false,
  }) async {
    final id = await db.customInsert(
      """
INSERT INTO ingredient(name, icon_asset_path, carbs_per_100g, fiber_per_100g,
 fat_per_100g, protein_per_100g, carbs_label_mode, nutrition_confidence, brand, barcode, is_reference)
SELECT ?, ?, ?, ?, ?, ?, ?, 0, NULL, NULL, 0
${onlyIfIdentityMissing ? "WHERE NOT EXISTS (SELECT 1 FROM ingredient_origin WHERE source = 'firebase' AND source_id = ?)" : ''}
""",
      variables: [
        Variable(ingredient.name),
        Variable<String>(ingredient.iconAssetPath),
        Variable(ingredient.carbsPer100g),
        Variable(ingredient.fiberPer100g),
        Variable(ingredient.fatPer100g),
        Variable(ingredient.proteinPer100g),
        Variable(ingredient.carbsLabelMode.storageValue),
        if (onlyIfIdentityMissing) Variable(ingredient.identity.sourceId),
      ],
      updates: {db.ingredient},
    );
    final changes = await db
        .customSelect('SELECT changes() AS affected')
        .getSingle();
    return changes.read<int>('affected') == 0 ? 0 : id;
  }

  static void validate(CatalogIngredient ingredient) {
    if (ingredient.identity.source != IngredientSource.firebase ||
        !ingredient.identity.isValid ||
        !RegExp(r'^usda_[1-9][0-9]*$').hasMatch(ingredient.identity.sourceId) ||
        ingredient.name.trim().isEmpty ||
        ingredient.revision.trim().isEmpty ||
        [
          ingredient.carbsPer100g,
          ingredient.fiberPer100g,
          ingredient.fatPer100g,
          ingredient.proteinPer100g,
        ].any((value) => !value.isFinite || value < 0 || value > 100) ||
        (ingredient.carbsLabelMode == CarbsLabelMode.nonEu &&
            ingredient.fiberPer100g > ingredient.carbsPer100g)) {
      throw ArgumentError('Catalog ingredient has invalid canonical nutrition');
    }
  }

  static Map<String, Object?> snapshot(CatalogIngredient ingredient) => {
    'identity': ingredient.identity.toJson(),
    'revision': ingredient.revision,
    'englishName': ingredient.englishName,
    'sourceName':
        ingredient.sourceName ?? ingredient.englishName ?? ingredient.name,
    'name': ingredient.name,
    'languageCode': ingredient.languageCode,
    'nutritionBasisGrams': 100,
    'carbsLabelMode': ingredient.carbsLabelMode.storageValue,
    'carbsPer100g': ingredient.carbsPer100g,
    'fiberPer100g': ingredient.fiberPer100g,
    'fatPer100g': ingredient.fatPer100g,
    'proteinPer100g': ingredient.proteinPer100g,
    'sourceKcalPer100g': ingredient.kcalPer100g,
  };
}
