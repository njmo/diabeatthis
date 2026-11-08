import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version 49 advice retains its legacy source after migration', () async {
    final directory = await Directory.systemTemp.createTemp(
      'caregiver-migration',
    );
    final file = File('${directory.path}/db.sqlite');
    var db = DatabaseImpl(NativeDatabase(file));
    try {
      await db.customStatement(
        "INSERT INTO meal (id, name, planned_at) VALUES (1, 'Meal', 1000)",
      );
      await db.customStatement(
        "INSERT INTO meal_advisor_result (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored) VALUES (1, 'manual', 0, 0, 0)",
      );
      await db.customStatement(
        'ALTER TABLE meal_advisor_result DROP COLUMN advice_source',
      );
      await db.customStatement(
        'ALTER TABLE meal_advisor_result DROP COLUMN caregiver_uid',
      );
      await db.customStatement(
        'ALTER TABLE meal_advisor_result DROP COLUMN caregiver_request_id',
      );
      await db.customStatement('DROP TABLE family_meal_decision_receipts');
      await db.customStatement('PRAGMA user_version = 49');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      final row = (await db.select(db.mealAdvisorResult).get()).single;
      expect(row.result, 'manual');
      expect(row.adviceSource, isNull);
      expect(row.caregiverUid, isNull);
      expect(row.caregiverRequestId, isNull);
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE name = 'family_meal_decision_receipts'",
            )
            .get(),
        hasLength(1),
      );
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
