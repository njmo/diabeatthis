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
import 'dao/meal_wizard_link_dao.dart';
import 'dao/portion_dao.dart';
import 'dao/quick_low_treatment_item_dao.dart';
import 'database.dart';
import 'migrations/migrate_stress_events.dart';
import 'migrations/migrate_wizard_identity.dart';

part 'database_impl.g.dart';

@DriftDatabase(
  include: {'schemas/schema.drift'},
  daos: [
    IngredientDao,
    PortionDao,
    MealDao,
    MealWizardLinkDao,
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
  int get schemaVersion => 33;

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
      if (from < 33) {
        await m.createTable(activitySchedule);
        await m.createTable(activityOccurrence);
        await customStatement('DROP INDEX IF EXISTS uq_only_one_open_session');
      }
      if (from < 32) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'accepted_meal_ai'",
        ).getSingleOrNull();
        if (existing == null) await m.createTable(acceptedMealAi);
      }
      if (from < 31) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'low_treatment_handoff'",
        ).getSingleOrNull();
        if (existing == null) await m.createTable(lowTreatmentHandoff);
      }
      if (from < 30) {
        final columns = await customSelect(
          'PRAGMA table_info(device_status)',
        ).get();
        if (!columns.any((row) => row.read<String>('name') == 'suggested_at')) {
          await m.addColumn(deviceStatus, deviceStatus.suggestedAt);
        }
      }
      if (from < 29) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'accepted_day_ai'",
        ).getSingleOrNull();
        if (existing == null) await m.createTable(acceptedDayAi);
      }
      if (from < 28) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'accepted_day_summary'",
        ).getSingleOrNull();
        if (existing == null) await m.createTable(acceptedDaySummary);
      }
      if (from < 27) {
        final existing = await customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'low_treatment_review'",
        ).getSingleOrNull();
        if (existing == null) await m.createTable(lowTreatmentReview);
      }
      if (from < 25) {
        await migrateWizardIdentity(this, m);
      }
      if (from < 26) {
        final columns = await customSelect(
          'PRAGMA table_info(meal_wizard_link)',
        ).get();
        if (!columns.any((row) => row.read<String>('name') == 'dismissed')) {
          await m.addColumn(mealWizardLink, mealWizardLink.dismissed);
        }
      }
      if (from < 24) {
        await m.addColumn(deviceStatus, deviceStatus.basalObservedAt);
        await m.addColumn(deviceStatus, deviceStatus.tempBasalAbsoluteRate);
        await m.addColumn(deviceStatus, deviceStatus.tempBasalStartedAt);
        await m.addColumn(deviceStatus, deviceStatus.enactedBasalRate);
        await m.addColumn(deviceStatus, deviceStatus.enactedBasalAt);
        await m.addColumn(
          deviceStatus,
          deviceStatus.enactedBasalDurationMinutes,
        );
        await m.addColumn(deviceStatus, deviceStatus.enactedBasalReceived);
      }
      if (from < 19 || (from >= 20 && from < 23)) {
        await m.alterTable(
          // ignore: experimental_member_use
          TableMigration(mealAdvisorResult),
        );
      }
      if (from < 22) {
        await m.addColumn(deviceStatus, deviceStatus.aapsPredictionsJson);
      }
      if (from < 21) {
        await m.addColumn(deviceStatus, deviceStatus.insulinActivityAt);
      }
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
      if (from < 14) {
        await m.addColumn(ingredient, ingredient.barcode);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS ingredient_barcode_unique ON ingredient(barcode) WHERE barcode IS NOT NULL',
        );
      }
      if (from < 16) {
        await migrateStressEvents(this, m);
      }
      if (from < 17) {
        await m.alterTable(
          // ignore: experimental_member_use
          TableMigration(
            glucoseReading,
            newColumns: [
              glucoseReading.type,
              glucoseReading.measurementId,
              glucoseReading.notes,
            ],
          ),
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
