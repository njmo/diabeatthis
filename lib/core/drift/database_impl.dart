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
  int get schemaVersion => 5;

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
      if (from < 5) {
        await _renameLocalGlucoseReadingTableIfNeeded();
        await _renameLocalDeviceStatusTableIfNeeded();
        await _addDeviceStatusSnapshotColumnsIfMissing();
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
    await _createGlucoseReadingTableIfMissing();
    await _createTreatmentMirrorTablesIfMissing();
    await _createDeviceStatusTableIfMissing();
  }

  Future<void> _createGlucoseReadingTableIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS glucose_reading (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps', 'xdrip')),
        external_id TEXT,
        recorded_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        sgv INTEGER NOT NULL CHECK (sgv >= 0),
        direction TEXT,
        UNIQUE (source, recorded_at, sgv)
      )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_glucose_reading_external_id
      ON glucose_reading(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_glucose_reading_recorded_at
      ON glucose_reading(recorded_at)
    ''');
  }

  Future<void> _createDeviceStatusTableIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS device_status (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        recorded_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        bg INTEGER CHECK (bg IS NULL OR bg >= 0),
        tick TEXT,
        iob REAL,
        basal_iob REAL,
        bolus_iob REAL,
        insulin_activity REAL,
        cob REAL,
        carbs_req REAL,
        carbs_req_within INTEGER,
        sensitivity_ratio REAL,
        isf_mgdl_for_carbs REAL,
        base_basal_rate REAL,
        temp_basal_remaining_minutes INTEGER,
        last_bolus_amount REAL,
        last_bolus_at TEXT,
        UNIQUE (source, recorded_at)
      )
    ''');
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_device_status_external_id
      ON device_status(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_device_status_recorded_at
      ON device_status(recorded_at)
    ''');
  }

  Future<void> _createTreatmentMirrorTablesIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS bolus_wizard (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        nightscout_id TEXT,
        glucose INTEGER,
        units TEXT,
        carbs REAL,
        insulin REAL,
        basal_iob REAL,
        bolus_iob REAL,
        carbs_insulin REAL,
        cob REAL,
        cob_insulin REAL,
        calculator_created_at INTEGER,
        glucose_difference REAL,
        glucose_insulin REAL,
        glucose_trend REAL,
        glucose_value REAL,
        ic REAL,
        calculator_id INTEGER,
        isf REAL,
        calculator_note TEXT,
        other_correction REAL,
        percentage_correction INTEGER,
        profile_name TEXT,
        superbolus_insulin REAL,
        target_bg_high REAL,
        target_bg_low REAL,
        calculator_timestamp INTEGER,
        trend_insulin REAL,
        utc_offset INTEGER,
        calculator_version INTEGER,
        was_basal_iob_used BOOLEAN,
        was_bolus_iob_used BOOLEAN,
        was_cob_used BOOLEAN,
        was_glucose_used BOOLEAN,
        was_superbolus_used BOOLEAN,
        was_temp_target_used BOOLEAN,
        was_trend_used BOOLEAN,
        were_carbs_used BOOLEAN,
        notes TEXT
      )
    ''');
    await _createTreatmentIndexes(
      table: 'bolus_wizard',
      externalIdIndex: 'uq_bolus_wizard_external_id',
      createdAtIndex: 'idx_bolus_wizard_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS temporary_target (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        nightscout_id TEXT,
        duration_minutes INTEGER,
        target_bottom REAL,
        target_top REAL
      )
    ''');
    await _createTreatmentIndexes(
      table: 'temporary_target',
      externalIdIndex: 'uq_temporary_target_external_id',
      createdAtIndex: 'idx_temporary_target_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS correction_bolus (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        insulin REAL
      )
    ''');
    await _createTreatmentIndexes(
      table: 'correction_bolus',
      externalIdIndex: 'uq_correction_bolus_external_id',
      createdAtIndex: 'idx_correction_bolus_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS manual_bolus (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        insulin REAL
      )
    ''');
    await _createTreatmentIndexes(
      table: 'manual_bolus',
      externalIdIndex: 'uq_manual_bolus_external_id',
      createdAtIndex: 'idx_manual_bolus_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS treat (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        carbs REAL
      )
    ''');
    await _createTreatmentIndexes(
      table: 'treat',
      externalIdIndex: 'uq_treat_external_id',
      createdAtIndex: 'idx_treat_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS extended_carb (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        carbs REAL,
        duration_minutes INTEGER
      )
    ''');
    await _createTreatmentIndexes(
      table: 'extended_carb',
      externalIdIndex: 'uq_extended_carb_external_id',
      createdAtIndex: 'idx_extended_carb_created_at',
    );
  }

  Future<void> _createTreatmentIndexes({
    required String table,
    required String externalIdIndex,
    required String createdAtIndex,
  }) async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS $externalIdIndex
      ON $table(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS $createdAtIndex
      ON $table(created_at)
    ''');
  }

  Future<void> _renameLocalDeviceStatusTableIfNeeded() async {
    final hasDeviceStatus = await _tableExists('device_status');
    if (hasDeviceStatus) return;

    final hasLocalDeviceStatus = await _tableExists('local_device_status');
    if (!hasLocalDeviceStatus) {
      await _createLocalMirrorTablesIfMissing();
      return;
    }

    await customStatement('''
      ALTER TABLE local_device_status
      RENAME TO device_status
    ''');
    await customStatement(
      'DROP INDEX IF EXISTS uq_local_device_status_external_id',
    );
    await customStatement(
      'DROP INDEX IF EXISTS idx_local_device_status_recorded_at',
    );
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_device_status_external_id
      ON device_status(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_device_status_recorded_at
      ON device_status(recorded_at)
    ''');
  }

  Future<void> _renameLocalGlucoseReadingTableIfNeeded() async {
    final hasGlucoseReading = await _tableExists('glucose_reading');
    if (hasGlucoseReading) return;

    final hasLocalGlucoseReading = await _tableExists('local_glucose_reading');
    if (!hasLocalGlucoseReading) {
      await _createLocalMirrorTablesIfMissing();
      return;
    }

    await customStatement('''
      ALTER TABLE local_glucose_reading
      RENAME TO glucose_reading
    ''');
    await customStatement(
      'DROP INDEX IF EXISTS uq_local_glucose_reading_external_id',
    );
    await customStatement(
      'DROP INDEX IF EXISTS idx_local_glucose_reading_recorded_at',
    );
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_glucose_reading_external_id
      ON glucose_reading(source, external_id)
      WHERE external_id IS NOT NULL
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_glucose_reading_recorded_at
      ON glucose_reading(recorded_at)
    ''');
  }

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable(name)],
    ).get();

    return rows.isNotEmpty;
  }

  Future<void> _addDeviceStatusSnapshotColumnsIfMissing() async {
    const columns = {
      'basal_iob': 'basal_iob REAL',
      'bolus_iob': 'bolus_iob REAL',
      'insulin_activity': 'insulin_activity REAL',
      'carbs_req': 'carbs_req REAL',
      'carbs_req_within': 'carbs_req_within INTEGER',
      'sensitivity_ratio': 'sensitivity_ratio REAL',
      'isf_mgdl_for_carbs': 'isf_mgdl_for_carbs REAL',
      'base_basal_rate': 'base_basal_rate REAL',
      'temp_basal_remaining_minutes': 'temp_basal_remaining_minutes INTEGER',
      'last_bolus_amount': 'last_bolus_amount REAL',
      'last_bolus_at': 'last_bolus_at TEXT',
    };

    for (final entry in columns.entries) {
      await _addDeviceStatusColumnIfMissing(
        name: entry.key,
        definition: entry.value,
      );
    }
  }

  Future<void> _addDeviceStatusColumnIfMissing({
    required String name,
    required String definition,
  }) async {
    final columns = await customSelect(
      'PRAGMA table_info(device_status)',
    ).get();
    final hasColumn = columns.any((row) => row.data['name'] == name);

    if (hasColumn) return;

    await customStatement('''
      ALTER TABLE device_status
      ADD COLUMN $definition
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
