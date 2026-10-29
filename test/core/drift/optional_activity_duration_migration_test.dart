import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version34ActivityDurationDatabase extends DatabaseImpl {
  Version34ActivityDurationDatabase(super.executor);

  @override
  int get schemaVersion => 34;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('DROP TABLE activity_occurrence');
      await customStatement('DROP TABLE activity_schedule');
      await customStatement('''CREATE TABLE activity_schedule (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      activity_id INTEGER NOT NULL REFERENCES activity(id) ON DELETE CASCADE,
      weekdays TEXT NOT NULL,
      start_minute INTEGER NOT NULL CHECK(start_minute BETWEEN 0 AND 1439),
      duration_minutes INTEGER NOT NULL CHECK(duration_minutes > 0),
      confirmation_mode TEXT NOT NULL CHECK(confirmation_mode IN ('before', 'previous_day', 'automatic')),
      previous_day_minute INTEGER NOT NULL DEFAULT 1140 CHECK(previous_day_minute BETWEEN 0 AND 1439),
      valid_from INTEGER NOT NULL,
      valid_until INTEGER,
      enabled BOOL NOT NULL DEFAULT 1
    )''');
      await customStatement('''CREATE TABLE activity_occurrence (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      schedule_id INTEGER REFERENCES activity_schedule(id) ON DELETE CASCADE,
      activity_id INTEGER NOT NULL REFERENCES activity(id) ON DELETE CASCADE,
      started_at INTEGER NOT NULL,
      duration_minutes INTEGER NOT NULL CHECK(duration_minutes > 0),
      action_at INTEGER NOT NULL,
      confirmation_mode TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      asked_at INTEGER,
      target_requested_at INTEGER,
      activity_log_id INTEGER REFERENCES activity_log(id) ON DELETE SET NULL,
      UNIQUE(schedule_id, started_at)
    )''');
    },
  );
}

void main() {
  test(
    'version 34 migration preserves durations, status, IDs and links and permits manual sessions',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'optional-activity-duration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version34ActivityDurationDatabase(NativeDatabase(file));
      await old
          .into(old.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Walk',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      await old
          .into(old.activityLog)
          .insert(
            ActivityLogCompanion.insert(activityId: 1, startedAt: 123000),
          );
      await old.customStatement(
        "INSERT INTO activity_schedule (id, activity_id, weekdays, start_minute, duration_minutes, confirmation_mode, valid_from) VALUES (41, 1, '4', 1080, 45, 'before', 0)",
      );
      await old.customStatement(
        "INSERT INTO activity_occurrence (id, schedule_id, activity_id, started_at, duration_minutes, action_at, confirmation_mode, status, asked_at, target_requested_at, activity_log_id) VALUES (51, 41, 1, 123000, 45, 120000, 'before', 'planned', 119000, 121000, 1)",
      );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final rule = (await db.select(db.activitySchedule).get()).single;
      final occurrence = (await db.select(db.activityOccurrence).get()).single;
      expect(rule.id, 41);
      expect(rule.durationMinutes, 45);
      expect(occurrence.id, 51);
      expect(occurrence.scheduleId, 41);
      expect(occurrence.activityLogId, 1);
      expect(occurrence.durationMinutes, 45);
      expect(occurrence.status, 'planned');
      expect(occurrence.askedAt, 119000);
      expect(occurrence.targetRequestedAt, 121000);
      await db
          .into(db.activityOccurrence)
          .insert(
            ActivityOccurrenceCompanion.insert(
              activityId: 1,
              startedAt: 456000,
              actionAt: 450000,
              confirmationMode: 'automatic',
              durationMinutes: const Value(null),
            ),
          );
      expect(
        (await db.select(db.activityOccurrence).get()).last.durationMinutes,
        isNull,
      );
      await db
          .into(db.activitySchedule)
          .insert(
            ActivityScheduleCompanion.insert(
              activityId: 1,
              weekdays: '4',
              startMinute: 1100,
              confirmationMode: 'before',
              validFrom: 0,
              durationMinutes: const Value(null),
            ),
          );
      expect(
        (await db.select(db.activitySchedule).get()).last.durationMinutes,
        isNull,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
