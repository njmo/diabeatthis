import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'v33 migration removes low treatment names and preserves relations and status history across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('typed-low-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      final at = DateTime(2026, 10, 28, 7, 50);
      final low = await db.mealDao.createLowTreatmentEntry(
        eatenAt: at,
        notes: 'Keep notes',
      );
      final breakfast = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Breakfast',
              plannedAt: at.millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      await db.lowTreatmentContextDao.upsertContextForMeal(
        LowTreatmentContextCompanion.insert(
          mealId: Value(low.id),
          source: 'manual',
          relatedMealId: Value(breakfast),
          reason: const Value('fallingTrend'),
        ),
      );
      final ingredient = await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'Glucose',
              carbsPer100g: 100,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
            ),
          );
      await db.insertMealIngredient(
        low.id,
        ingredient,
        null,
        10,
        null,
        1,
        null,
      );
      await db.mealDao.updateMealStatus(breakfast, 'summarized');
      await db.close();

      // Rebuild only the meal table with the real v33 table-level unique constraint.
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('PRAGMA foreign_keys = OFF');
      final originalSql =
          legacy
                  .select(
                    "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'meal'",
                  )
                  .single['sql']
              as String;
      final triggers = legacy
          .select(
            "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'meal'",
          )
          .map((row) => row['sql'] as String)
          .toList();
      var tableSql = originalSql.replaceFirst(
        RegExp(r'CREATE TABLE\s+"?meal"?'),
        'CREATE TABLE meal_legacy',
      );
      final closing = tableSql.lastIndexOf(')');
      tableSql =
          '${tableSql.substring(0, closing)}, UNIQUE (name, planned_at)${tableSql.substring(closing)}';
      legacy.execute(tableSql);
      legacy.execute('INSERT INTO meal_legacy SELECT * FROM meal');
      legacy.execute('DROP TABLE meal');
      legacy.execute('ALTER TABLE meal_legacy RENAME TO meal');
      legacy.execute(
        "UPDATE meal SET name = 'Dosłodzenie (2)' WHERE purpose = 'lowTreatment'",
      );
      for (final trigger in triggers) {
        legacy.execute(trigger);
      }
      legacy.execute('PRAGMA user_version = 33');
      legacy.dispose();

      db = DatabaseImpl(NativeDatabase(file));
      final migrated = (await db.mealDao.getMealById(low.id))!;
      expect(migrated.name, '');
      expect(migrated.purpose, 'lowTreatment');
      expect(migrated.plannedAt, low.plannedAt);
      expect(migrated.createdAt, low.createdAt);
      expect(migrated.updatedAt, low.updatedAt);
      expect(migrated.notes, 'Keep notes');
      final ingredients = await db.mealIngredientsDao.getMealIngredientsForMeal(
        low.id,
      );
      expect(ingredients, hasLength(1));
      expect(ingredients.single.amount, 10);
      expect(
        (await db.lowTreatmentContextDao.getContextForMeal(
          low.id,
        ))!.relatedMealId,
        breakfast,
      );
      expect((await db.mealDao.getMealById(breakfast))!.name, 'Breakfast');
      final another = await db.mealDao.createLowTreatmentEntry(eatenAt: at);
      expect(another.id, isNot(low.id));
      expect(another.name, '');
      await expectLater(
        db
            .into(db.meal)
            .insert(
              MealCompanion.insert(
                name: 'Breakfast',
                plannedAt: at.millisecondsSinceEpoch,
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await db.mealDao.updateMealStatus(breakfast, 'eaten');
      expect(
        await (db.select(
          db.mealStatusHistory,
        )..where((row) => row.mealId.equals(breakfast))).get(),
        hasLength(2),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      expect((await db.mealDao.getMealById(low.id))!.name, '');
      expect((await db.mealDao.getMealById(another.id))!.name, '');
    },
  );
}
