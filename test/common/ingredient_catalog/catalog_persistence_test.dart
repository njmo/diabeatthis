import 'dart:io';

import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_ingredient_origin_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_local_ingredient_search_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/drift_selected_catalog_ingredient_store.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/mappers/ingredient_drift_mapper.dart';
import 'package:diabeatthis/core/drift/migrations/migrate_ingredient_origin.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/copy_catalog_ingredient_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/domain/use_cases/update_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogIngredient catalogItem({
  String id = 'usda_123',
  String revision = 'v1',
  double carbs = 28,
}) => CatalogIngredient(
  identity: IngredientIdentity(source: IngredientSource.firebase, sourceId: id),
  name: 'Ryż gotowany',
  englishName: 'Rice, cooked',
  languageCode: 'pl',
  revision: revision,
  carbsPer100g: carbs,
  fiberPer100g: 2,
  fatPer100g: 1,
  proteinPer100g: 3,
  carbsLabelMode: CarbsLabelMode.nonEu,
);

Future<int> insertLocal(DatabaseImpl db) => db.customInsert(
  '''
INSERT INTO ingredient(name,carbs_per_100g,fiber_per_100g,fat_per_100g,protein_per_100g,nutrition_confidence)
VALUES ('Ryż gotowany', 10, 1, 2, 3, .8)
''',
  updates: {db.ingredient},
);

void main() {
  test(
    'default origins and mirrors never merge by product name and never refresh facts implicitly',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final localId = await insertLocal(db);
      final first = await store.mirror(catalogItem());
      final second = await store.mirror(catalogItem(id: 'usda_456'));
      expect({localId, first, second}.length, 3);
      expect(
        await store.findLocalId(
          IngredientIdentity(
            source: IngredientSource.local,
            sourceId: '$localId',
          ),
        ),
        localId,
      );
      expect(await store.mirror(catalogItem(revision: 'v2', carbs: 40)), first);
      final row = await db.ingredientDao.getIngredientById(first);
      expect(row.carbsPer100g, 28);
      expect(row.fiberPer100g, 2);
      expect(row.nutritionConfidence, 0);
      final origin = await db
          .customSelect(
            'SELECT * FROM ingredient_origin WHERE ingredient_id = $first',
          )
          .getSingle();
      expect(origin.read<String>('source_revision'), 'v1');
      expect(origin.read<String>('confidence_origin'), 'unassessed');
      expect(origin.read<String>('creation_method'), 'catalog_mirror');
      final search = await DriftLocalIngredientSearchRepository(
        db,
      ).search('ryz gotowany');
      expect(search.map((item) => item.identity.stableKey).toSet().length, 3);
      expect(search.where((item) => item.isRemote).length, 2);
    },
  );

  test(
    'independent copy and photo provenance stay local without modifying catalog mirror',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final mirror = await store.mirror(catalogItem());
      final copy = await store.copyAsLocal(catalogItem());
      final photo = await insertLocal(db);
      await store.recordPhotoReferenceOrigin(
        photo,
        referenceScope: 'component',
        provenance: {'schemaVersion': 1, 'estimatedGrams': 150},
      );
      expect(await store.findLocalId(catalogItem().identity), mirror);
      expect(
        await store.findLocalId(
          IngredientIdentity(source: IngredientSource.local, sourceId: '$copy'),
        ),
        copy,
      );
      final origin = await db
          .customSelect(
            'SELECT * FROM ingredient_origin WHERE ingredient_id = $photo',
          )
          .getSingle();
      expect(origin.read<String>('creation_method'), 'photo_reference');
      expect(origin.read<String>('reference_scope'), 'component');
      await expectLater(
        store.recordPhotoReferenceOrigin(
          mirror,
          referenceScope: 'whole_plate',
          provenance: {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'core backup preserves remote identity and source facts; legacy backup backfills only missing origins',
    () async {
      final source = DatabaseImpl(NativeDatabase.memory());
      final restored = DatabaseImpl(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(restored.close);
      final id = await DriftSelectedCatalogIngredientStore(
        source,
      ).mirror(catalogItem());
      final backup = await DatabaseBackupService(
        source,
      ).exportToJson(DatabaseBackupScope.core);
      await DatabaseBackupService(restored).importFromJson(backup);
      expect(
        await DriftSelectedCatalogIngredientStore(
          restored,
        ).findLocalId(catalogItem().identity),
        id,
      );
      final origins = await restored
          .customSelect('SELECT * FROM ingredient_origin')
          .get();
      expect(origins.single.read<String>('source_revision'), 'v1');
      final tables = backup['tables'] as Map<String, Object?>;
      tables.remove('ingredient_origin');
      await DatabaseBackupService(restored).importFromJson(backup);
      final legacy = await restored
          .customSelect('SELECT * FROM ingredient_origin')
          .get();
      expect(legacy.single.read<String>('source'), 'local');
      final next = await insertLocal(restored);
      expect(
        await DriftSelectedCatalogIngredientStore(restored).findLocalId(
          IngredientIdentity(source: IngredientSource.local, sourceId: '$next'),
        ),
        next,
      );
    },
  );

  test(
    'upgrade from 45 backfills local identity without changing nutrition or ingredient IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ingredient-origin-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.sqlite');
      final old = DatabaseImpl(NativeDatabase(file));
      final id = await insertLocal(old);
      await old.customStatement('DROP TRIGGER ingredient_origin_default_local');
      await old.customStatement(
        'DROP TRIGGER ingredient_catalog_facts_immutable',
      );
      await old.customStatement('DROP TABLE ingredient_origin');
      await old.customStatement('PRAGMA user_version = 45');
      await old.close();
      final upgraded = DatabaseImpl(NativeDatabase(file));
      addTearDown(upgraded.close);
      final row = await upgraded.ingredientDao.getIngredientById(id);
      expect(row.carbsPer100g, 10);
      expect(row.nutritionConfidence, .8);
      expect(
        await DriftSelectedCatalogIngredientStore(upgraded).findLocalId(
          IngredientIdentity(source: IngredientSource.local, sourceId: '$id'),
        ),
        id,
      );
    },
  );
  test(
    'finalized origin rejects reassignment and deletion; parent deletion cascades while copy keeps its source snapshot',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final mirror = await store.mirror(catalogItem());
      final copy = await store.copyAsLocal(catalogItem());
      await expectLater(
        db.customStatement(
          "UPDATE ingredient_origin SET source_revision = 'tampered' WHERE ingredient_id = $mirror",
        ),
        throwsException,
      );
      await expectLater(
        db.customStatement(
          'DELETE FROM ingredient_origin WHERE ingredient_id = $mirror',
        ),
        throwsException,
      );
      await db.customStatement('DELETE FROM ingredient WHERE id = $mirror');
      expect(await store.findLocalId(catalogItem().identity), isNull);
      final row = await db
          .customSelect(
            'SELECT copied_from_json FROM ingredient_origin WHERE ingredient_id = $copy',
          )
          .getSingle();
      expect(row.read<String>('copied_from_json'), contains('usda_123'));
      expect(row.read<String>('copied_from_json'), contains('v1'));
      final photo = await insertLocal(db);
      await store.recordPhotoReferenceOrigin(
        photo,
        referenceScope: 'component',
        provenance: {'schemaVersion': 1},
      );
      await expectLater(
        store.recordPhotoReferenceOrigin(
          photo,
          referenceScope: 'whole_plate',
          provenance: {'schemaVersion': 1},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'invalid restored references roll back the whole import and retain existing origins',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final id = await store.mirror(catalogItem());
      final backup = await DatabaseBackupService(
        db,
      ).exportToJson(DatabaseBackupScope.core);
      final tables = backup['tables'] as Map<String, Object?>;
      final rows = tables['ingredient_origin'] as List;
      (rows.single as Map)['ingredient_id'] = 999999;
      await expectLater(
        DatabaseBackupService(db).importFromJson(backup),
        throwsStateError,
      );
      expect(await store.findLocalId(catalogItem().identity), id);
      await expectLater(
        db.customStatement(
          'DELETE FROM ingredient_origin WHERE ingredient_id = $id',
        ),
        throwsException,
      );
    },
  );

  test(
    'two database connections selecting the same identity produce one canonical mirror',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'catalog-concurrent-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.sqlite');
      final first = DatabaseImpl(NativeDatabase(file));
      await first.customSelect('SELECT 1').get();
      final second = DatabaseImpl(NativeDatabase(file));
      await second.customSelect('SELECT 1').get();
      addTearDown(first.close);
      addTearDown(second.close);
      final ids = await Future.wait([
        DriftSelectedCatalogIngredientStore(first).mirror(catalogItem()),
        DriftSelectedCatalogIngredientStore(second).mirror(catalogItem()),
      ]);
      expect(ids[0], ids[1]);
      expect(
        (await first.customSelect('SELECT * FROM ingredient').get()).length,
        1,
      );
    },
  );

  test(
    'catalog write boundary and database reject edits; explicit copy remains editable with durable source facts',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final id = await store.mirror(catalogItem());
      final original = (await db.ingredientDao.getIngredientById(
        id,
      )).toDomain().toDraft();
      await expectLater(
        container.read(updateIngredientDetailsUseCaseProvider)(
          original.copyWith(carbsPer100g: 50),
        ),
        throwsStateError,
      );
      await expectLater(
        db.customStatement(
          'UPDATE ingredient SET carbs_per_100g = 50 WHERE id = $id',
        ),
        throwsException,
      );
      expect((await db.ingredientDao.getIngredientById(id)).carbsPer100g, 28);
      final copiedId = await container.read(
        copyCatalogIngredientUseCaseProvider,
      )(id);
      final copied = (await db.ingredientDao.getIngredientById(
        copiedId,
      )).toDomain().toDraft();
      await container.read(updateIngredientDetailsUseCaseProvider)(
        copied.copyWith(carbsPer100g: 50, nutritionConfidence: .8),
      );
      expect(
        (await db.ingredientDao.getIngredientById(copiedId)).carbsPer100g,
        50,
      );
      expect((await db.ingredientDao.getIngredientById(id)).carbsPer100g, 28);
      final origin = await db
          .customSelect(
            'SELECT * FROM ingredient_origin WHERE ingredient_id = $copiedId',
          )
          .getSingle();
      expect(origin.read<String>('copied_from_json'), contains('usda_123'));
      expect(origin.read<String>('confidence_origin'), 'user_assessed');
    },
  );

  test(
    'UI-created local copy preserves the exact canonical source snapshot including source energy and translated display',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final ingredient = CatalogIngredient(
        identity: catalogItem().identity,
        name: 'Ryż gotowany',
        englishName: 'Rice, cooked, original USDA name',
        languageCode: 'pl',
        revision: 'original-revision',
        carbsPer100g: 28,
        fiberPer100g: 2,
        fatPer100g: 1,
        proteinPer100g: 3,
        carbsLabelMode: CarbsLabelMode.nonEu,
        kcalPer100g: 133,
      );
      final id = await DriftSelectedCatalogIngredientStore(
        db,
      ).mirror(ingredient);
      final source = await db
          .customSelect(
            'SELECT source_snapshot_json FROM ingredient_origin WHERE ingredient_id = $id',
          )
          .getSingle();
      final copy = await container.read(copyCatalogIngredientUseCaseProvider)(
        id,
      );
      final copied = await db
          .customSelect(
            'SELECT copied_from_json FROM ingredient_origin WHERE ingredient_id = $copy',
          )
          .getSingle();
      expect(
        copied.read<String>('copied_from_json'),
        source.read<String>('source_snapshot_json'),
      );
      expect(copied.read<String>('copied_from_json'), contains('133'));
      expect(
        copied.read<String>('copied_from_json'),
        contains('original USDA name'),
      );
      expect((await db.ingredientDao.getIngredientById(copy)).carbsPer100g, 28);
    },
  );

  test(
    'origin migration is idempotent when a historic fixture already has the current tables',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      final id = await store.mirror(catalogItem());
      final before =
          (await db
                  .customSelect(
                    'SELECT * FROM ingredient_origin WHERE ingredient_id = $id',
                  )
                  .getSingle())
              .data;
      await migrateIngredientOrigin(db);
      await migrateIngredientOrigin(db);
      expect(
        (await db
                .customSelect(
                  'SELECT * FROM ingredient_origin WHERE ingredient_id = $id',
                )
                .getSingle())
            .data,
        before,
      );
      expect((await db.ingredientDao.getIngredientById(id)).carbsPer100g, 28);
    },
  );

  test(
    'explicit confidence assessment updates copy metadata even when the chosen confidence is zero',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);
      final store = DriftSelectedCatalogIngredientStore(db);
      for (final confidence in [0.0, .9]) {
        final id = await store.copyAsLocal(catalogItem());
        final draft = (await db.ingredientDao.getIngredientById(
          id,
        )).toDomain().toDraft();
        await container.read(updateIngredientDetailsUseCaseProvider)(
          draft.copyWith(nutritionConfidence: confidence),
          nutritionConfidenceAssessed: true,
        );
        final origin = await db
            .customSelect(
              'SELECT confidence_origin FROM ingredient_origin WHERE ingredient_id = $id',
            )
            .getSingle();
        expect(origin.read<String>('confidence_origin'), 'user_assessed');
        expect(
          (await db.ingredientDao.getIngredientById(id)).nutritionConfidence,
          confidence,
        );
      }
    },
  );

  test(
    'origin repository resolves immutable provenance and explicitly assesses only local copies',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final origins = DriftIngredientOriginRepository(db);
      final store = DriftSelectedCatalogIngredientStore(db);
      expect(await origins.read(99999), isNull);
      final mirror = await store.mirror(catalogItem());
      final external = (await origins.read(mirror))!;
      expect(external.identity, catalogItem().identity);
      expect(external.sourceRevision, 'v1');
      expect(external.nutritionConfidenceAssessed, false);
      expect(external.creationMethod, 'catalog_mirror');
      expect(external.englishName, 'Rice, cooked');
      expect(external.sourceSnapshotJson, contains('usda_123'));
      await expectLater(
        origins.markConfidenceAssessed(mirror),
        throwsStateError,
      );
      final copied = await store.copyAsLocal(catalogItem());
      expect((await origins.read(copied))!.nutritionConfidenceAssessed, false);
      await origins.markConfidenceAssessed(copied);
      final assessed = (await origins.read(copied))!;
      expect(assessed.nutritionConfidenceAssessed, true);
      expect(
        assessed.identity,
        IngredientIdentity(source: IngredientSource.local, sourceId: '$copied'),
      );
      expect(assessed.copiedFromJson, contains('usda_123'));
      expect((await origins.read(mirror))!.nutritionConfidenceAssessed, false);
    },
  );
}
