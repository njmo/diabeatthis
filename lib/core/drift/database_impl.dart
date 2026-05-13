import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'dao/activity_dao.dart';
import 'dao/ingredient_dao.dart';
import 'dao/local_mirror_dao.dart';
import 'dao/meal_advisor_result_dao.dart';
import 'dao/meal_dao.dart';
import 'dao/meal_ingredients_dao.dart';
import 'dao/meal_template_dao.dart';
import 'dao/meal_template_ingredients_dao.dart';
import 'dao/portion_dao.dart';
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
  ],
)
class DatabaseImpl extends _$DatabaseImpl implements Database {
  DatabaseImpl([QueryExecutor? executor])
    : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

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
      if (from < 2) {
        await _addActivityDurationColumnIfMissing();
      }
      if (from < 3) {
        await _addMealAdvisorExtendedCarbsColumnsIfMissing();
      }
      if (from < 4) {
        await _createLocalMirrorTablesIfMissing();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _addActivityDurationColumnIfMissing() async {
    final columns = await customSelect('PRAGMA table_info(activity)').get();
    final hasDurationColumn = columns.any(
      (row) => row.data['name'] == 'duration_minutes',
    );

    if (hasDurationColumn) return;

    await customStatement('''
      ALTER TABLE activity
      ADD COLUMN duration_minutes INTEGER
      CHECK (duration_minutes IS NULL OR duration_minutes > 0)
    ''');
  }

  Future<void> _addMealAdvisorExtendedCarbsColumnsIfMissing() async {
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_grams',
      definition: 'extended_carbs_grams INTEGER NOT NULL DEFAULT 0',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_delivery_mode',
      definition: 'extended_carbs_delivery_mode TEXT',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_delay_minutes',
      definition: 'extended_carbs_delay_minutes INTEGER',
    );
    await _addMealAdvisorResultColumnIfMissing(
      name: 'extended_carbs_duration_minutes',
      definition: 'extended_carbs_duration_minutes INTEGER',
    );
  }

  Future<void> _addMealAdvisorResultColumnIfMissing({
    required String name,
    required String definition,
  }) async {
    final columns = await customSelect(
      'PRAGMA table_info(meal_advisor_result)',
    ).get();
    final hasColumn = columns.any((row) => row.data['name'] == name);

    if (hasColumn) return;

    await customStatement('''
      ALTER TABLE meal_advisor_result
      ADD COLUMN $definition
    ''');
  }

  Future<void> _createLocalMirrorTablesIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_glucose_reading (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps', 'xdrip')),
        external_id TEXT,
        recorded_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        sgv INTEGER NOT NULL CHECK (sgv >= 0),
        direction TEXT,
        tick INTEGER,
        raw_json TEXT,
        UNIQUE (source, recorded_at, sgv)
      )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_local_glucose_reading_external_id
      ON local_glucose_reading(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_glucose_reading_recorded_at
      ON local_glucose_reading(recorded_at)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_treatment_event (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        treatment_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        nightscout_id TEXT,
        carbs REAL,
        insulin REAL,
        duration_minutes INTEGER,
        target_bottom REAL,
        target_top REAL,
        units TEXT,
        notes TEXT,
        raw_json TEXT
      )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_local_treatment_event_external_id
      ON local_treatment_event(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_treatment_event_created_at
      ON local_treatment_event(created_at)
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS local_device_status (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        recorded_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        bg INTEGER CHECK (bg IS NULL OR bg >= 0),
        tick TEXT,
        iob REAL,
        cob REAL,
        pump_json TEXT,
        openaps_json TEXT,
        raw_json TEXT,
        UNIQUE (source, recorded_at)
      )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_local_device_status_external_id
      ON local_device_status(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_local_device_status_recorded_at
      ON local_device_status(recorded_at)
    ''');
  }

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
