import 'dart:io';

import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'migrates local mirror tables from synthetic ids to timestamp keys',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'local_mirror_migration_',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');

      final sqliteDb = sqlite.sqlite3.open(file.path);
      try {
        _createLegacyMirrorTables(sqliteDb);
        _insertLegacyRows(sqliteDb);
        sqliteDb.execute('PRAGMA user_version = 5');
      } finally {
        sqliteDb.dispose();
      }

      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);

      final glucoseColumns = await _columnNames(db, 'glucose_reading');
      final deviceStatusColumns = await _columnNames(db, 'device_status');
      final manualBolusColumns = await _columnNames(db, 'manual_bolus');

      expect(glucoseColumns, isNot(contains('id')));
      expect(glucoseColumns, contains('created_at'));
      expect(glucoseColumns, isNot(contains('recorded_at')));
      expect(deviceStatusColumns, isNot(contains('id')));
      expect(deviceStatusColumns, contains('created_at'));
      expect(deviceStatusColumns, isNot(contains('recorded_at')));
      expect(manualBolusColumns, isNot(contains('id')));
      expect(manualBolusColumns, contains('created_at'));

      final glucose = await db.localMirrorDao.getGlucoseReadingsBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
      expect(glucose, hasLength(1));
      expect(glucose.single.source, BgSource.xdrip.storageValue);
      expect(glucose.single.sgv, 121);

      final deviceStatuses = await db.localMirrorDao.getDeviceStatusesBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
      expect(deviceStatuses, hasLength(1));
      expect(deviceStatuses.single.source, EventSource.aaps.storageValue);
      expect(deviceStatuses.single.bg, 111);

      final manualBoluses = await db.localMirrorDao.getManualBolusesBetween(
        DateTime.fromMillisecondsSinceEpoch(0),
        DateTime.fromMillisecondsSinceEpoch(2000),
      );
      expect(manualBoluses, hasLength(1));
      expect(manualBoluses.single.source, EventSource.aaps.storageValue);
      expect(manualBoluses.single.insulin, 2.5);
    },
  );

  test('migrates bolus wizard boolean storage to integers', () async {
    final dir = await Directory.systemTemp.createTemp(
      'bolus_wizard_boolean_migration_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    final sqliteDb = sqlite.sqlite3.open(file.path);
    try {
      _createBooleanBolusWizardTable(sqliteDb);
      _insertBooleanBolusWizard(sqliteDb);
      sqliteDb.execute('PRAGMA user_version = 6');
    } finally {
      sqliteDb.dispose();
    }

    final db = DatabaseImpl(NativeDatabase(file));
    addTearDown(db.close);

    final boolColumnTypes = await _columnTypes(db, 'bolus_wizard');
    expect(boolColumnTypes['was_basal_iob_used'], 'INTEGER');
    expect(boolColumnTypes['were_carbs_used'], 'INTEGER');

    final bolusWizards = await db.localMirrorDao.getBolusWizardsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );
    expect(bolusWizards, hasLength(1));
    expect(bolusWizards.single.wasBasalIobUsed, isTrue);
    expect(bolusWizards.single.wereCarbsUsed, isFalse);
  });

  test('migrates glucose and device status timestamps to created_at', () async {
    final dir = await Directory.systemTemp.createTemp(
      'mirror_created_at_migration_',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/db.sqlite');

    final sqliteDb = sqlite.sqlite3.open(file.path);
    try {
      _createRecordedAtMirrorTables(sqliteDb);
      _insertRecordedAtMirrorRows(sqliteDb);
      sqliteDb.execute('PRAGMA user_version = 7');
    } finally {
      sqliteDb.dispose();
    }

    final db = DatabaseImpl(NativeDatabase(file));
    addTearDown(db.close);

    final glucoseColumns = await _columnNames(db, 'glucose_reading');
    final deviceStatusColumns = await _columnNames(db, 'device_status');

    expect(glucoseColumns, contains('created_at'));
    expect(glucoseColumns, isNot(contains('recorded_at')));
    expect(deviceStatusColumns, contains('created_at'));
    expect(deviceStatusColumns, isNot(contains('recorded_at')));

    final glucose = await db.localMirrorDao.getGlucoseReadingsBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );
    expect(glucose.single.sgv, 121);

    final deviceStatuses = await db.localMirrorDao.getDeviceStatusesBetween(
      DateTime.fromMillisecondsSinceEpoch(0),
      DateTime.fromMillisecondsSinceEpoch(2000),
    );
    expect(deviceStatuses.single.bg, 111);
  });
}

Future<Set<String>> _columnNames(DatabaseImpl db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((row) => row.data['name'] as String).toSet();
}

Future<Map<String, String>> _columnTypes(DatabaseImpl db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return {
    for (final row in rows)
      row.data['name'] as String: (row.data['type'] as String).toUpperCase(),
  };
}

void _createLegacyMirrorTables(sqlite.Database db) {
  db.execute('''
    CREATE TABLE glucose_reading (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      external_id TEXT,
      recorded_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      sgv INTEGER NOT NULL,
      direction TEXT
    );
  ''');
  db.execute(
    'CREATE INDEX idx_glucose_reading_recorded_at ON glucose_reading(recorded_at);',
  );

  db.execute('''
    CREATE TABLE device_status (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      external_id TEXT,
      recorded_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      bg INTEGER,
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
      last_bolus_at TEXT
    );
  ''');
  db.execute(
    'CREATE INDEX idx_device_status_recorded_at ON device_status(recorded_at);',
  );

  db.execute('''
    CREATE TABLE manual_bolus (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      external_id TEXT,
      created_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      insulin REAL
    );
  ''');
  db.execute(
    'CREATE INDEX idx_manual_bolus_created_at ON manual_bolus(created_at);',
  );
}

void _insertLegacyRows(sqlite.Database db) {
  db.execute('''
    INSERT INTO glucose_reading
      (source, external_id, recorded_at, received_at, sgv, direction)
    VALUES
      ('cloud', 'sgv-cloud', 1000, 1000, 120, 'Flat'),
      ('xdrip', NULL, 1000, 2000, 121, 'FortyFiveUp');
  ''');
  db.execute('''
    INSERT INTO device_status
      (source, external_id, recorded_at, received_at, bg, iob, cob)
    VALUES
      ('cloud', 'status-cloud', 1000, 1000, 110, 1.2, 10),
      ('aaps', NULL, 1000, 2000, 111, 1.3, 9);
  ''');
  db.execute('''
    INSERT INTO manual_bolus
      (source, external_id, created_at, received_at, insulin)
    VALUES
      ('cloud', 'bolus-cloud', 1000, 1000, 2.0),
      ('aaps', NULL, 1000, 2000, 2.5);
  ''');
}

void _createBooleanBolusWizardTable(sqlite.Database db) {
  db.execute('''
    CREATE TABLE bolus_wizard (
      source TEXT NOT NULL,
      external_id TEXT,
      created_at INTEGER NOT NULL PRIMARY KEY,
      received_at INTEGER NOT NULL,
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
    );
  ''');
  db.execute(
    'CREATE INDEX idx_bolus_wizard_created_at ON bolus_wizard(created_at);',
  );
}

void _insertBooleanBolusWizard(sqlite.Database db) {
  db.execute('''
    INSERT INTO bolus_wizard
      (source, external_id, created_at, received_at, nightscout_id,
       was_basal_iob_used, were_carbs_used)
    VALUES
      ('cloud', 'bolus-wizard-cloud', 1000, 1000, 'bolus-wizard-cloud',
       1, 0);
  ''');
}

void _createRecordedAtMirrorTables(sqlite.Database db) {
  db.execute('''
    CREATE TABLE glucose_reading (
      source TEXT NOT NULL,
      external_id TEXT,
      recorded_at INTEGER NOT NULL PRIMARY KEY,
      received_at INTEGER NOT NULL,
      sgv INTEGER NOT NULL,
      direction TEXT
    );
  ''');
  db.execute(
    'CREATE INDEX idx_glucose_reading_recorded_at ON glucose_reading(recorded_at);',
  );
  db.execute('''
    CREATE TABLE device_status (
      source TEXT NOT NULL,
      external_id TEXT,
      recorded_at INTEGER NOT NULL PRIMARY KEY,
      received_at INTEGER NOT NULL,
      bg INTEGER,
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
      last_bolus_at TEXT
    );
  ''');
  db.execute(
    'CREATE INDEX idx_device_status_recorded_at ON device_status(recorded_at);',
  );
}

void _insertRecordedAtMirrorRows(sqlite.Database db) {
  db.execute('''
    INSERT INTO glucose_reading
      (source, external_id, recorded_at, received_at, sgv, direction)
    VALUES
      ('cloud', 'sgv-cloud', 1000, 1000, 121, 'Flat');
  ''');
  db.execute('''
    INSERT INTO device_status
      (source, external_id, recorded_at, received_at, bg, iob, cob)
    VALUES
      ('cloud', 'status-cloud', 1000, 1000, 111, 1.3, 9);
  ''');
}
