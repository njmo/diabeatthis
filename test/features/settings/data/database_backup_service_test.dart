import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('exports and imports core database tables only', () async {
    await _seedFullDatabase(db);

    final backup = await DatabaseBackupService(
      db,
    ).exportToJson(DatabaseBackupScope.core);

    final tables = backup['tables']! as Map<String, Object?>;
    expect(tables.keys, containsAll(DatabaseBackupService.coreTableNames));
    expect(tables.keys, isNot(contains('meal')));
    expect(tables.keys, isNot(contains('activity_log')));

    final targetDb = DatabaseImpl(NativeDatabase.memory());
    addTearDown(targetDb.close);

    final result = await DatabaseBackupService(targetDb).importFromJson(backup);

    expect(result.scope, DatabaseBackupScope.core);
    expect(result.rowCount, 6);
    expect(await _countRows(targetDb, 'ingredient'), 1);
    expect(await _countRows(targetDb, 'portion'), 1);
    expect(await _countRows(targetDb, 'ingredient_portions'), 1);
    expect(await _countRows(targetDb, 'activity'), 1);
    expect(await _countRows(targetDb, 'meal_template'), 1);
    expect(await _countRows(targetDb, 'meal_template_ingredients'), 1);
    expect(await _countRows(targetDb, 'meal'), 0);
    expect(await _countRows(targetDb, 'activity_log'), 0);
  });

  test('clears history and meals while keeping core database tables', () async {
    await _seedFullDatabase(db);

    await DatabaseBackupService(db).clearHistoryKeepingCoreData();

    expect(await _countRows(db, 'ingredient'), 1);
    expect(await _countRows(db, 'portion'), 1);
    expect(await _countRows(db, 'ingredient_portions'), 1);
    expect(await _countRows(db, 'activity'), 1);
    expect(await _countRows(db, 'meal_template'), 1);
    expect(await _countRows(db, 'meal_template_ingredients'), 1);
    expect(await _countRows(db, 'meal'), 0);
    expect(await _countRows(db, 'meal_ingredients'), 0);
    expect(await _countRows(db, 'activity_log'), 0);
    expect(await _countRows(db, 'meal_snapshot'), 0);
    expect(await _countRows(db, 'meal_advisor_result'), 0);
  });
}

Future<void> _seedFullDatabase(DatabaseImpl db) async {
  await db.customInsert('''
    INSERT INTO ingredient (
      id,
      name,
      carbs_per_100g,
      fat_per_100g,
      fiber_per_100g,
      protein_per_100g,
      nutrition_confidence,
      brand
    ) VALUES (1, 'Rice', 28, 0.3, 0.4, 2.7, 0.75, 'Test')
  ''');
  await db.customInsert('''
    INSERT INTO portion (id, name, unit_hint)
    VALUES (1, 'Spoon', 'pcs')
  ''');
  await db.customInsert('''
    INSERT INTO ingredient_portions (
      ingredient_id,
      portion_id,
      grams_per_portion
    ) VALUES (1, 1, 12)
  ''');
  await db.customInsert('''
    INSERT INTO activity (
      id,
      name,
      percentage_pre,
      percentage_post
    ) VALUES (1, 'Walk', 80, 90)
  ''');
  await db.customInsert('''
    INSERT INTO activity_log (
      id,
      activity_id,
      started_at,
      ended_at
    ) VALUES (1, 1, 1700000000000, 1700003600000)
  ''');
  await db.customInsert('''
    INSERT INTO meal_template (id, name, notes)
    VALUES (1, 'Breakfast', 'Template note')
  ''');
  await db.customInsert('''
    INSERT INTO meal_template_ingredients (
      meal_template_id,
      ingredient_id,
      portion_id,
      default_amount,
      quantity_confidence
    ) VALUES (1, 1, 1, 2, 0.8)
  ''');
  await db.customInsert('''
    INSERT INTO meal (
      id,
      name,
      planned_at,
      meal_template_id
    ) VALUES (1, 'Breakfast', 1700000000000, 1)
  ''');
  await db.customInsert('''
    INSERT INTO meal_ingredients (
      id,
      meal_id,
      ingredient_id,
      portion_id,
      amount,
      quantity_confidence
    ) VALUES (1, 1, 1, 1, 2, 0.8)
  ''');
  await db.customInsert('''
    INSERT INTO meal_snapshot (
      id,
      meal_id,
      snapshot_type,
      total_grams,
      total_carbs_g,
      total_fiber_g,
      total_net_carbs_g,
      total_fat_g,
      total_protein_g,
      total_calories_kcal
    ) VALUES (1, 1, 'planned', 24, 6.7, 0.1, 6.6, 0.1, 0.6, 29)
  ''');
  await db.customInsert('''
    INSERT INTO meal_advisor_result (
      meal_id,
      result,
      initial_wait_time,
      final_wait_time,
      wait_time_ignored
    ) VALUES (1, 'eat_now', 0, 0, 0)
  ''');
}

Future<int> _countRows(DatabaseImpl db, String tableName) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $tableName')
      .getSingle();
  return row.read<int>('c');
}
