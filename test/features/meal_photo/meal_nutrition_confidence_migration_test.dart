import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'version 46 meal upgrades with null override and keeps its original confidence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'meal-confidence-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final current = DatabaseImpl(NativeDatabase(file));
      await current.customStatement(
        "INSERT INTO ingredient(id,name,carbs_per_100g,fiber_per_100g,fat_per_100g,protein_per_100g,nutrition_confidence,is_reference) "
        "VALUES(1,'Rice',20,2,1,3,0.6,0)",
      );
      await current.customStatement(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Legacy meal',1,'planned')",
      );
      await current.customStatement(
        'INSERT INTO meal_ingredients(meal_id,ingredient_id,amount,quantity_confidence) VALUES(1,1,100,0.5)',
      );
      await current.close();
      final legacy = sqlite3.open(file.path);
      legacy.execute('DROP TRIGGER meal_ingredients_summary_set_updated_at');
      legacy.execute(
        'ALTER TABLE meal_ingredients DROP COLUMN nutrition_confidence_override',
      );
      legacy.execute('PRAGMA user_version = 46');
      legacy.dispose();
      final upgraded = DatabaseImpl(NativeDatabase(file));
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(upgraded)],
      );
      addTearDown(() async {
        container.dispose();
        await upgraded.close();
      });
      final rows = await upgraded.select(upgraded.mealIngredients).get();
      expect(rows.single.nutritionConfidenceOverride, isNull);
      await container
          .read(mealSnapshotControllerProvider)
          .createPlannedSnapshot(1);
      final snapshot =
          (await upgraded.select(upgraded.mealSnapshot).get()).single;
      expect(snapshot.carbWeightedNutritionConfidence, closeTo(.6, 1e-12));
      expect(
        (await upgraded.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        47,
      );
    },
  );
}
