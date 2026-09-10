import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/basal_schema_columns.dart';

void main() {
  for (final oldVersion in [17, 18, 19, 20, 21, 22]) {
    test('version $oldVersion keeps existing advice and removes redundant fields', () async {
      final directory = await Directory.systemTemp.createTemp(
        'meal-migration-',
      );
      final file = File('${directory.path}/database.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      try {
        await db.customSelect('SELECT 1 FROM meal').get();
        await db.customStatement(
          "INSERT INTO meal (name, planned_at) VALUES ('Existing meal', 1000)",
        );
        await db.customStatement('DROP TABLE meal_advisor_result');
        await db.customStatement('''
        CREATE TABLE meal_advisor_result (
          meal_id INTEGER NOT NULL PRIMARY KEY REFERENCES meal(id) ON DELETE CASCADE,
          result TEXT NOT NULL, initial_wait_time INTEGER NOT NULL,
          final_wait_time INTEGER NOT NULL, wait_time_ignored BOOL NOT NULL,
          extended_carbs_grams INTEGER NOT NULL DEFAULT 0,
          extended_carbs_delivery_mode TEXT, extended_carbs_delay_minutes INTEGER,
          extended_carbs_duration_minutes INTEGER, decision_reason TEXT,
          version INTEGER DEFAULT 2, is_synced BOOL NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 1000,
          updated_at INTEGER NOT NULL DEFAULT 1000
        )
      ''');
        await db.customStatement(
          '''CREATE TRIGGER meal_advisor_result_any_change_marks_unsynced
        AFTER UPDATE ON meal_advisor_result FOR EACH ROW WHEN NEW.is_synced <> 0
        BEGIN UPDATE meal_advisor_result SET is_synced = 0 WHERE meal_id = NEW.meal_id; END''',
        );
        await db.customStatement(
          "INSERT INTO meal_advisor_result (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored, extended_carbs_grams, extended_carbs_delivery_mode, extended_carbs_delay_minutes, extended_carbs_duration_minutes, decision_reason, created_at) VALUES (1, 'bolused-waiting', 15, 12, 1, 18, 'extendedCarbs', 45, 120, 'highBgNotFalling', 1234)",
        );
        if (oldVersion == 18) {
          await db.customStatement(
            "ALTER TABLE meal_advisor_result ADD COLUMN decision_source TEXT NOT NULL DEFAULT 'manual'",
          );
          await db.customStatement(
            'ALTER TABLE meal_advisor_result ADD COLUMN is_retrospective BOOL NOT NULL DEFAULT 1',
          );
          await db.customStatement(
            'ALTER TABLE meal_advisor_result ADD COLUMN declared_bolus_at INTEGER',
          );
          await db.customStatement(
            'ALTER TABLE meal_advisor_result ADD COLUMN eating_duration_minutes INTEGER',
          );
        }
        if (oldVersion >= 20) {
          await db.customStatement(
            'ALTER TABLE meal_advisor_result ADD COLUMN decision_context_json TEXT',
          );
          await db.customStatement(
            "UPDATE meal_advisor_result SET decision_context_json = '{\"inputs\":{\"bg\":120}}' WHERE meal_id = 1",
          );
        }
        if (oldVersion < 22) {
          await db.customStatement(
            'ALTER TABLE device_status DROP COLUMN aaps_predictions_json',
          );
        }
        if (oldVersion < 21) {
          await db.customStatement(
            'ALTER TABLE device_status DROP COLUMN insulin_activity_at',
          );
        }
        for (final column in basalSchemaColumns) {
          await db.customStatement(
            'ALTER TABLE device_status DROP COLUMN $column',
          );
        }
        await db.customStatement('PRAGMA user_version = $oldVersion');
        await db.close();
        db = DatabaseImpl(NativeDatabase(file));
        final result = (await db.select(db.mealAdvisorResult).get()).single;
        expect(result.result, 'bolused-waiting');
        final columns =
            (await db
                    .customSelect('PRAGMA table_info(meal_advisor_result)')
                    .get())
                .map((row) => row.read<String>('name'));
        expect(columns, isNot(contains('decision_source')));
        expect(columns, isNot(contains('is_retrospective')));
        expect(columns, isNot(contains('declared_bolus_at')));
        expect(columns, isNot(contains('eating_duration_minutes')));
        expect(result.version, 2);
        expect(columns, isNot(contains('decision_context_json')));
        expect(result.initialWaitTime, 15);
        expect(result.finalWaitTime, 12);
        expect(result.waitTimeIgnored, isTrue);
        expect(result.extendedCarbsGrams, 18);
        expect(result.extendedCarbsDeliveryMode, 'extendedCarbs');
        expect(result.extendedCarbsDelayMinutes, 45);
        expect(result.extendedCarbsDurationMinutes, 120);
        expect(result.decisionReason, 'highBgNotFalling');
        expect(result.createdAt, 1234);
        await db.customStatement(
          "UPDATE meal_advisor_result SET result = 'manual', version = NULL, is_synced = 1 WHERE meal_id = 1",
        );
        final changed = (await db.select(db.mealAdvisorResult).get()).single;
        expect(changed.version, isNull);
        expect(changed.isSynced, isFalse);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    });
  }
}
