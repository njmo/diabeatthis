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
  int get schemaVersion => 8;

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
      if (from < 6) {
        await _rebuildLocalMirrorTablesWithoutSyntheticIds();
      }
      if (from < 7) {
        await _rebuildBolusWizardBooleanColumnsAsIntegers();
      }
      if (from < 8) {
        await _rebuildGlucoseAndDeviceStatusWithCreatedAt();
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

  Future<void> _rebuildLocalMirrorTablesWithoutSyntheticIds() async {
    await _rebuildMirrorTableWithoutSyntheticId(
      table: 'glucose_reading',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'sgv',
        'direction',
      ],
      dropIndexes: [
        'uq_glucose_reading_external_id',
        'idx_glucose_reading_recorded_at',
        'idx_glucose_reading_created_at',
      ],
      createTable: _createGlucoseReadingTableIfMissing,
    );
    await _rebuildMirrorTableWithoutSyntheticId(
      table: 'device_status',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'bg',
        'tick',
        'iob',
        'basal_iob',
        'bolus_iob',
        'insulin_activity',
        'cob',
        'carbs_req',
        'carbs_req_within',
        'sensitivity_ratio',
        'isf_mgdl_for_carbs',
        'base_basal_rate',
        'temp_basal_remaining_minutes',
        'last_bolus_amount',
        'last_bolus_at',
      ],
      dropIndexes: [
        'uq_device_status_external_id',
        'idx_device_status_recorded_at',
        'idx_device_status_created_at',
      ],
      createTable: _createDeviceStatusTableIfMissing,
    );

    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'bolus_wizard',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'nightscout_id',
        'glucose',
        'units',
        'carbs',
        'insulin',
        'basal_iob',
        'bolus_iob',
        'carbs_insulin',
        'cob',
        'cob_insulin',
        'calculator_created_at',
        'glucose_difference',
        'glucose_insulin',
        'glucose_trend',
        'glucose_value',
        'ic',
        'calculator_id',
        'isf',
        'calculator_note',
        'other_correction',
        'percentage_correction',
        'profile_name',
        'superbolus_insulin',
        'target_bg_high',
        'target_bg_low',
        'calculator_timestamp',
        'trend_insulin',
        'utc_offset',
        'calculator_version',
        'was_basal_iob_used',
        'was_bolus_iob_used',
        'was_cob_used',
        'was_glucose_used',
        'was_superbolus_used',
        'was_temp_target_used',
        'was_trend_used',
        'were_carbs_used',
        'notes',
      ],
      externalIdIndex: 'uq_bolus_wizard_external_id',
      createdAtIndex: 'idx_bolus_wizard_created_at',
    );
    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'temporary_target',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'nightscout_id',
        'duration_minutes',
        'target_bottom',
        'target_top',
      ],
      externalIdIndex: 'uq_temporary_target_external_id',
      createdAtIndex: 'idx_temporary_target_created_at',
    );
    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'correction_bolus',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'insulin',
      ],
      externalIdIndex: 'uq_correction_bolus_external_id',
      createdAtIndex: 'idx_correction_bolus_created_at',
    );
    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'manual_bolus',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'insulin',
      ],
      externalIdIndex: 'uq_manual_bolus_external_id',
      createdAtIndex: 'idx_manual_bolus_created_at',
    );
    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'treat',
      columns: ['source', 'external_id', 'created_at', 'received_at', 'carbs'],
      externalIdIndex: 'uq_treat_external_id',
      createdAtIndex: 'idx_treat_created_at',
    );
    await _rebuildTreatmentMirrorTableWithoutSyntheticId(
      table: 'extended_carb',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'carbs',
        'duration_minutes',
      ],
      externalIdIndex: 'uq_extended_carb_external_id',
      createdAtIndex: 'idx_extended_carb_created_at',
    );
  }

  Future<void> _rebuildTreatmentMirrorTableWithoutSyntheticId({
    required String table,
    required List<String> columns,
    required String externalIdIndex,
    required String createdAtIndex,
  }) {
    return _rebuildMirrorTableWithoutSyntheticId(
      table: table,
      columns: columns,
      dropIndexes: [externalIdIndex, createdAtIndex],
      createTable: _createTreatmentMirrorTablesIfMissing,
    );
  }

  Future<void> _rebuildBolusWizardBooleanColumnsAsIntegers() async {
    if (!await _tableExists('bolus_wizard')) return;

    final booleanColumns = await customSelect(
      'PRAGMA table_info(bolus_wizard)',
    ).get();
    final hasBooleanStorageType = booleanColumns.any(
      (row) => (row.data['type'] as String?)?.toUpperCase() == 'BOOLEAN',
    );
    if (!hasBooleanStorageType) return;

    const table = 'bolus_wizard';
    const oldTable = 'bolus_wizard_with_boolean_columns';
    const columns = [
      'source',
      'external_id',
      'created_at',
      'received_at',
      'nightscout_id',
      'glucose',
      'units',
      'carbs',
      'insulin',
      'basal_iob',
      'bolus_iob',
      'carbs_insulin',
      'cob',
      'cob_insulin',
      'calculator_created_at',
      'glucose_difference',
      'glucose_insulin',
      'glucose_trend',
      'glucose_value',
      'ic',
      'calculator_id',
      'isf',
      'calculator_note',
      'other_correction',
      'percentage_correction',
      'profile_name',
      'superbolus_insulin',
      'target_bg_high',
      'target_bg_low',
      'calculator_timestamp',
      'trend_insulin',
      'utc_offset',
      'calculator_version',
      'was_basal_iob_used',
      'was_bolus_iob_used',
      'was_cob_used',
      'was_glucose_used',
      'was_superbolus_used',
      'was_temp_target_used',
      'was_trend_used',
      'were_carbs_used',
      'notes',
    ];
    final columnList = columns.join(', ');

    await customStatement('ALTER TABLE $table RENAME TO $oldTable');
    await customStatement('DROP INDEX IF EXISTS idx_bolus_wizard_created_at');
    await customStatement('DROP INDEX IF EXISTS uq_bolus_wizard_external_id');
    await _createTreatmentMirrorTablesIfMissing();
    await customStatement('''
      INSERT OR REPLACE INTO $table ($columnList)
      SELECT $columnList
      FROM $oldTable
      ORDER BY received_at ASC
    ''');
    await customStatement('DROP TABLE $oldTable');
  }

  Future<void> _rebuildGlucoseAndDeviceStatusWithCreatedAt() async {
    await _rebuildMirrorTableWithCreatedAt(
      table: 'glucose_reading',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'sgv',
        'direction',
      ],
      dropIndexes: [
        'idx_glucose_reading_recorded_at',
        'idx_glucose_reading_created_at',
      ],
      createTable: _createGlucoseReadingTableIfMissing,
    );
    await _rebuildMirrorTableWithCreatedAt(
      table: 'device_status',
      columns: [
        'source',
        'external_id',
        'created_at',
        'received_at',
        'bg',
        'tick',
        'iob',
        'basal_iob',
        'bolus_iob',
        'insulin_activity',
        'cob',
        'carbs_req',
        'carbs_req_within',
        'sensitivity_ratio',
        'isf_mgdl_for_carbs',
        'base_basal_rate',
        'temp_basal_remaining_minutes',
        'last_bolus_amount',
        'last_bolus_at',
      ],
      dropIndexes: [
        'idx_device_status_recorded_at',
        'idx_device_status_created_at',
      ],
      createTable: _createDeviceStatusTableIfMissing,
    );
  }

  Future<void> _rebuildMirrorTableWithCreatedAt({
    required String table,
    required List<String> columns,
    required List<String> dropIndexes,
    required Future<void> Function() createTable,
  }) async {
    if (!await _tableExists(table)) return;
    if (!await _tableHasColumn(table, 'recorded_at')) return;

    final oldTable = '${table}_with_recorded_at';
    final columnList = columns.join(', ');
    final selectColumnList = columns
        .map((column) => column == 'created_at' ? 'recorded_at' : column)
        .join(', ');

    await customStatement('ALTER TABLE $table RENAME TO $oldTable');
    for (final index in dropIndexes) {
      await customStatement('DROP INDEX IF EXISTS $index');
    }

    await createTable();
    await customStatement('''
      INSERT OR REPLACE INTO $table ($columnList)
      SELECT $selectColumnList
      FROM $oldTable
      ORDER BY received_at ASC
    ''');
    await customStatement('DROP TABLE $oldTable');
  }

  Future<void> _rebuildMirrorTableWithoutSyntheticId({
    required String table,
    required List<String> columns,
    required List<String> dropIndexes,
    required Future<void> Function() createTable,
  }) async {
    if (!await _tableExists(table)) return;
    if (!await _tableHasColumn(table, 'id')) return;

    final existingColumns = await _tableColumns(table);
    final oldTable = '${table}_with_id';
    final columnList = columns.join(', ');
    final selectColumnList = columns
        .map(
          (column) =>
              column == 'created_at' &&
                  !existingColumns.contains('created_at') &&
                  existingColumns.contains('recorded_at')
              ? 'recorded_at'
              : column,
        )
        .join(', ');

    await customStatement('ALTER TABLE $table RENAME TO $oldTable');
    for (final index in dropIndexes) {
      await customStatement('DROP INDEX IF EXISTS $index');
    }

    await createTable();
    await customStatement('''
      INSERT OR REPLACE INTO $table ($columnList)
      SELECT $selectColumnList
      FROM $oldTable
      ORDER BY received_at ASC
    ''');
    await customStatement('DROP TABLE $oldTable');
  }

  Future<void> _createGlucoseReadingTableIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS glucose_reading (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps', 'xdrip')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        sgv INTEGER NOT NULL CHECK (sgv >= 0),
        direction TEXT,
        PRIMARY KEY (created_at)
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_glucose_reading_created_at
      ON glucose_reading(created_at)
    ''');
  }

  Future<void> _createDeviceStatusTableIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS device_status (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
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
        PRIMARY KEY (created_at)
      )
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_device_status_created_at
      ON device_status(created_at)
    ''');
  }

  Future<void> _createTreatmentMirrorTablesIfMissing() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS bolus_wizard (
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
        was_basal_iob_used INTEGER,
        was_bolus_iob_used INTEGER,
        was_cob_used INTEGER,
        was_glucose_used INTEGER,
        was_superbolus_used INTEGER,
        was_temp_target_used INTEGER,
        was_trend_used INTEGER,
        were_carbs_used INTEGER,
        notes TEXT,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'bolus_wizard',
      createdAtIndex: 'idx_bolus_wizard_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS temporary_target (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        nightscout_id TEXT,
        duration_minutes INTEGER,
        target_bottom REAL,
        target_top REAL,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'temporary_target',
      createdAtIndex: 'idx_temporary_target_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS correction_bolus (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        insulin REAL,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'correction_bolus',
      createdAtIndex: 'idx_correction_bolus_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS manual_bolus (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        insulin REAL,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'manual_bolus',
      createdAtIndex: 'idx_manual_bolus_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS treat (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        carbs REAL,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'treat',
      createdAtIndex: 'idx_treat_created_at',
    );

    await customStatement('''
      CREATE TABLE IF NOT EXISTS extended_carb (
        source TEXT NOT NULL CHECK (source IN ('cloud', 'aaps')),
        external_id TEXT,
        created_at INTEGER NOT NULL,
        received_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s','now') AS INTEGER) * 1000),
        carbs REAL,
        duration_minutes INTEGER,
        PRIMARY KEY (created_at)
      )
    ''');
    await _createTreatmentIndexes(
      table: 'extended_carb',
      createdAtIndex: 'idx_extended_carb_created_at',
    );
  }

  Future<void> _createTreatmentIndexes({
    required String table,
    required String createdAtIndex,
  }) async {
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

  Future<Set<String>> _tableColumns(String table) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.map((row) => row.data['name'] as String).toSet();
  }

  Future<bool> _tableHasColumn(String table, String column) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    return columns.any((row) => row.data['name'] == column);
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
    if (await _tableHasColumn('device_status', name)) return;

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
