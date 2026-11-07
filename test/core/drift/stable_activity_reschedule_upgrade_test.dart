import 'dart:io';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'version 48 upgrade preserves history and creates empty reschedule metadata',
    () async {
      final dir = await Directory.systemTemp.createTemp('stable-reschedule-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/database.sqlite');
      final initial = DatabaseImpl(NativeDatabase(file));
      await initial.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Training',20,30)",
      );
      await initial.customStatement(
        "INSERT INTO activity_occurrence(activity_id,started_at,action_at,confirmation_mode,status) VALUES(1,1000,1000,'before','skipped')",
      );
      await initial.close();
      final raw = sqlite3.open(file.path);
      raw.execute('DROP TABLE activity_schedule_exception');
      raw.execute('DROP TABLE activity_occurrence_reschedule');
      raw.execute('PRAGMA user_version=48');
      raw.dispose();
      final upgraded = DatabaseImpl(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(
        (await upgraded.select(upgraded.activityOccurrence).getSingle()).status,
        'skipped',
      );
      expect(
        await upgraded.select(upgraded.activityScheduleException).get(),
        isEmpty,
      );
      expect(
        await upgraded.select(upgraded.activityOccurrenceReschedule).get(),
        isEmpty,
      );
      expect(
        await upgraded.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'full backup retains moved identity and prevents the original slot from returning',
    () => withClock(Clock.fixed(DateTime(2026, 11, 7, 12)), () async {
      final source = DatabaseImpl(NativeDatabase.memory());
      final restored = DatabaseImpl(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(restored.close);
      await source.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Training',20,30)",
      );
      final service = ActivityScheduleService(source);
      await service.save(
        activityId: 1,
        weekdays: {3},
        startMinute: 17 * 60,
        durationMinutes: 43,
        mode: 'before',
        validFrom: DateTime(2026, 11, 7),
      );
      final original = await source
          .select(source.activityOccurrence)
          .getSingle();
      final destination = DateTime.fromMillisecondsSinceEpoch(
        original.startedAt,
      ).add(const Duration(hours: 1));
      await service.move(original.id, destination);
      final backup = await DatabaseBackupService(
        source,
      ).exportToJson(DatabaseBackupScope.full);
      await DatabaseBackupService(restored).importFromJson(backup);
      await ActivityScheduleService(restored).refresh();
      final row = await restored
          .select(restored.activityOccurrence)
          .getSingle();
      expect(row.id, original.id);
      expect(row.startedAt, destination.millisecondsSinceEpoch);
      expect(row.durationMinutes, 43);
      expect(
        (await restored.select(restored.activityScheduleException).getSingle())
            .startedAt,
        original.startedAt,
      );
      expect(
        (await restored
                .select(restored.activityOccurrenceReschedule)
                .getSingle())
            .originalStartedAt,
        original.startedAt,
      );
      expect(
        await restored.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    }),
  );
}
