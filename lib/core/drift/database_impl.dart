import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'dao/activity_dao.dart';
import 'dao/ingredient_dao.dart';
import 'dao/local_mirror_dao.dart';
import 'dao/low_treatment_context_dao.dart';
import 'dao/meal_advisor_result_dao.dart';
import 'dao/meal_dao.dart';
import 'dao/meal_ingredients_dao.dart';
import 'dao/meal_template_dao.dart';
import 'dao/meal_template_ingredients_dao.dart';
import 'dao/portion_dao.dart';
import 'dao/quick_low_treatment_item_dao.dart';
import 'database.dart';

part 'database_impl.g.dart';

@DriftDatabase(
  include: {'schemas/schema.drift'},
  daos: [
    IngredientDao,
    PortionDao,
    MealDao,
    MealAdvisorResultDao,
    LocalMirrorDao,
    ActivityDao,
    MealTemplateDao,
    MealIngredientsDao,
    MealTemplateIngredientsDao,
    LowTreatmentContextDao,
    QuickLowTreatmentItemDao,
  ],
)
class DatabaseImpl extends _$DatabaseImpl implements Database {
  DatabaseImpl([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 13;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 9) {
        await m.addColumn(meal, meal.purpose);
        await m.createTable(lowTreatmentContext);
      }
      if (from < 10) {
        await m.createTable(quickLowTreatmentItem);
      }
      if (from < 11) {
        await customStatement(createIngredientPortionsUnsyncedTrigger);
      }
      if (from < 12) {
        await m.addColumn(
          lowTreatmentContext,
          lowTreatmentContext.relatedActivityLogId,
        );
      }
      if (from < 13) {
        await m.alterTable(
          // ignore: experimental_member_use
          TableMigration(ingredient, newColumns: [ingredient.carbsLabelMode]),
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement(
        'DROP TRIGGER IF EXISTS ingredient_nutrition_changed',
      );
      await customStatement(createIngredientNutritionChangedTrigger);
      await customStatement(
        'DROP TRIGGER IF EXISTS ingredient_portions_any_change_marks_unsynced',
      );
      await customStatement(createIngredientPortionsUnsyncedTrigger);
    },
  );

  Future<void> deleteEverything() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in allTables) {
          await delete(table).go();
        }
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}

const createIngredientNutritionChangedTrigger = '''
CREATE TRIGGER ingredient_nutrition_changed
AFTER UPDATE OF carbs_per_100g, fat_per_100g, fiber_per_100g, protein_per_100g, nutrition_confidence
ON ingredient
FOR EACH ROW
WHEN
  OLD.carbs_per_100g IS NOT NEW.carbs_per_100g OR
  OLD.fat_per_100g IS NOT NEW.fat_per_100g OR
  OLD.fiber_per_100g IS NOT NEW.fiber_per_100g OR
  OLD.protein_per_100g IS NOT NEW.protein_per_100g OR
  OLD.nutrition_confidence IS NOT NEW.nutrition_confidence
BEGIN
  INSERT INTO ingredient_status_history (
    ingredient_id,
    carbs_per_100g,
    fat_per_100g,
    fiber_per_100g,
    protein_per_100g,
    nutrition_confidence
  )
  VALUES (
    OLD.id,
    OLD.carbs_per_100g,
    OLD.fat_per_100g,
    OLD.fiber_per_100g,
    OLD.protein_per_100g,
    OLD.nutrition_confidence
  );
END;
''';

const createIngredientPortionsUnsyncedTrigger = '''
CREATE TRIGGER ingredient_portions_any_change_marks_unsynced
AFTER UPDATE OF grams_per_portion ON ingredient_portions
FOR EACH ROW
WHEN OLD.grams_per_portion IS NOT NEW.grams_per_portion
  AND NEW.is_synced <> 0
BEGIN
  UPDATE ingredient_portions
  SET is_synced = 0
  WHERE ingredient_id = NEW.ingredient_id
    AND portion_id = NEW.portion_id;
END;
''';
