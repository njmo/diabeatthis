import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version36IngredientDatabase extends DatabaseImpl {
  Version36IngredientDatabase(super.executor);

  @override
  int get schemaVersion => 36;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // This later-added trigger references the icon column absent in v36.
      await customStatement(
        'DROP TRIGGER IF EXISTS ingredient_catalog_facts_immutable',
      );
      await customStatement(
        'ALTER TABLE ingredient DROP COLUMN icon_asset_path',
      );
    },
  );
}

void main() {
  test(
    'version 36 ingredients survive upgrade and can receive full asset paths',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ingredient-icon-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version36IngredientDatabase(NativeDatabase(file));
      final oldColumns = await old
          .customSelect('PRAGMA table_info(ingredient)')
          .get();
      expect(
        oldColumns.map((row) => row.read<String>('name')),
        isNot(contains('icon_asset_path')),
      );
      await old.customStatement(
        "INSERT INTO ingredient(name, carbs_per_100g, fat_per_100g, fiber_per_100g, protein_per_100g, nutrition_confidence, is_reference) VALUES ('Burger', 20, 10, 1, 10, 0.5, 1)",
      );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final before = await db.select(db.ingredient).getSingle();
      expect(before.name, 'Burger');
      expect(before.iconAssetPath, isNull);
      expect(before.carbsPer100g, 20);
      await db.customStatement(
        "UPDATE ingredient SET icon_asset_path = 'assets/icons/food/hamburger.png'",
      );
      final after = await db.select(db.ingredient).getSingle();
      expect(after.iconAssetPath, 'assets/icons/food/hamburger.png');
      expect(await db.select(db.ingredientStatusHistory).get(), isEmpty);
    },
  );
}
