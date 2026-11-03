import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_ingredient_amounts_repository.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version44PortionDatabase extends DatabaseImpl {
  Version44PortionDatabase(super.executor);

  @override
  int get schemaVersion => 44;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('DROP TRIGGER meal_ingredients_capture_portion');
      await customStatement(
        'DROP TRIGGER meal_ingredients_summary_set_updated_at',
      );
      await customStatement(
        'ALTER TABLE meal_ingredients DROP COLUMN grams_per_portion_used',
      );
      await customStatement(
        'ALTER TABLE meal_snapshot DROP COLUMN calculated_at',
      );
      await customStatement(
        """CREATE TRIGGER meal_ingredients_summary_set_updated_at AFTER UPDATE ON meal_ingredients FOR EACH ROW WHEN NEW.updated_at = OLD.updated_at BEGIN UPDATE meal_ingredients SET updated_at = (CAST(strftime('%s','now') AS INTEGER) * 1000) WHERE id = NEW.id; END""",
      );
    },
  );
}

void main() {
  test(
    'migration preserves aggregates and does not invent legacy conversion or calculation time',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recorded-portions-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version44PortionDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO ingredient (id,name,carbs_per_100g,fiber_per_100g,fat_per_100g,protein_per_100g,nutrition_confidence) VALUES (1,'Bread',50,0,0,0,1)",
      );
      await old.customStatement(
        "INSERT INTO portion (id,name,unit_hint) VALUES (1,'Slice','piece')",
      );
      await old.customStatement(
        'INSERT INTO ingredient_portions (ingredient_id,portion_id,grams_per_portion) VALUES (1,1,40)',
      );
      for (final id in [1, 2]) {
        await old.customStatement(
          "INSERT INTO meal (id,name,planned_at,status) VALUES ($id,'Recorded meal $id',1000,'summarized')",
        );
        await old.customStatement(
          'INSERT INTO meal_ingredients (meal_id,ingredient_id,portion_id,amount,consumed_amount,quantity_confidence) VALUES ($id,1,1,2,2,1)',
        );
        await old.customStatement(
          "INSERT INTO meal_snapshot (meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,created_at,updated_at) VALUES ($id,'consumed',60,30,0,30,0,0,120,1000,${id == 1 ? 1000 : 2000})",
        );
      }
      await old.close();

      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final entries = await db.select(db.mealIngredients).get();
      expect(entries, hasLength(2));
      expect(
        entries.every((entry) => entry.gramsPerPortionUsed == null),
        isTrue,
      );
      final amounts = await MealIngredientAmountsRepository(
        db,
      ).load(entries.first);
      expect(amounts.conversionAvailable, isFalse);
      expect(amounts.consumedGrams, 0);
      await expectLater(db.ingredientDao.totalsForMeal(1), throwsStateError);
      final snapshots = await db.select(db.mealSnapshot).get();
      expect(snapshots.map((row) => row.totalGrams), [60, 60]);
      expect(snapshots.map((row) => row.totalNetCarbsG), [30, 30]);
      expect(
        snapshots.singleWhere((row) => row.mealId == 1).calculatedAt,
        1000,
      );
      expect(
        snapshots.singleWhere((row) => row.mealId == 2).calculatedAt,
        isNull,
      );
    },
  );
}
