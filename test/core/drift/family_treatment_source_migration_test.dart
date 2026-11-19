import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

Future<File> legacyDatabase(
  Directory directory, {
  bool corrupt = false,
  int version = 50,
}) async {
  final file = File('${directory.path}/medical.sqlite');
  final db = DatabaseImpl(NativeDatabase(file));
  await db.customStatement(
    "INSERT INTO meal(id,name,planned_at,status,purpose) VALUES(1,'',1000,'confirmed','lowTreatment')",
  );
  await db.customStatement(
    "INSERT INTO low_treatment_context(meal_id,source,recorded_carbs,reason,created_at,updated_at,is_synced) VALUES(1,'manual',12,'manual',77,88,1)",
  );
  if (version == 51) {
    await db.customStatement(
      "INSERT INTO meal(id,name,planned_day) VALUES(2,'Untimed','2026-11-19')",
    );
  }
  await db.close();
  final raw = sqlite.sqlite3.open(file.path);
  try {
    final sql =
        raw
                .select(
                  "SELECT sql FROM sqlite_master WHERE name='low_treatment_context'",
                )
                .single['sql']
            as String;
    final triggers = raw
        .select(
          "SELECT sql FROM sqlite_master WHERE type='trigger' AND tbl_name='low_treatment_context'",
        )
        .map((row) => row['sql'] as String)
        .toList();
    final oldSql = sql
        .replaceAll(RegExp(r",\s*'familyChat'"), '')
        .replaceFirst('low_treatment_context', 'old_context');
    raw.execute(oldSql);
    raw.execute('INSERT INTO old_context SELECT * FROM low_treatment_context');
    raw.execute('DROP TABLE low_treatment_context');
    raw.execute('ALTER TABLE old_context RENAME TO low_treatment_context');
    for (final trigger in triggers) {
      raw.execute(trigger);
    }
    if (corrupt) {
      raw.execute('PRAGMA ignore_check_constraints=ON');
      raw.execute("UPDATE low_treatment_context SET source='invalid'");
    }
    raw.execute('PRAGMA user_version=$version');
  } finally {
    raw.dispose();
  }
  return file;
}

void main() {
  for (final version in [50, 51]) {
    test(
      'version $version upgrade preserves context, timestamps and triggers',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'family-source-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await legacyDatabase(directory, version: version);
        final db = DatabaseImpl(NativeDatabase(file));
        addTearDown(db.close);
        final row = (await db.select(db.lowTreatmentContext).get()).single;
        expect(row.source, 'manual');
        expect(row.recordedCarbs, 12);
        expect(row.createdAt, 77);
        expect(row.updatedAt, 88);
        expect(row.isSynced, true);
        if (version == 51) {
          final untimed = await db.mealDao.getMealById(2);
          expect(untimed?.plannedAt, isNull);
          expect(untimed?.plannedDay, '2026-11-19');
        }
        await db.customStatement(
          "UPDATE low_treatment_context SET source='familyChat' WHERE meal_id=1",
        );
        final changed = (await db.select(db.lowTreatmentContext).get()).single;
        expect(changed.source, 'familyChat');
        expect(changed.isSynced, false);
        expect(changed.updatedAt, isNot(88));
        expect(
          (await db.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty,
        );
      },
    );
  }

  test(
    'failed context migration leaves the old database and version intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-source-rollback-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await legacyDatabase(directory, corrupt: true);
      final db = DatabaseImpl(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT * FROM low_treatment_context').get(),
        throwsA(anything),
      );
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      try {
        expect(raw.select('PRAGMA user_version').single.values.single, 50);
        expect(
          raw
              .select('SELECT source FROM low_treatment_context')
              .single['source'],
          'invalid',
        );
        expect(
          raw.select(
            "SELECT name FROM sqlite_master WHERE name LIKE 'tmp_for_migration_%'",
          ),
          isEmpty,
        );
      } finally {
        raw.dispose();
      }
    },
  );
}
