import 'dart:io';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'version 32 upgrade preserves activity history and allows several reservations',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'activity-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final initial = DatabaseImpl(NativeDatabase(file));
      await initial
          .into(initial.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'PE',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      await initial.activityDao.insertActivityLog(
        ActivityLogCompanion.insert(activityId: 1, startedAt: 1000),
      );
      await initial.close();

      // Reconstruct the version-32 activity schema: the new tables did not exist
      // and a unique index allowed only one unfinished session.
      final legacy = sqlite3.open(file.path);
      legacy.execute('DROP TABLE activity_occurrence');
      legacy.execute('DROP TABLE activity_schedule');
      legacy.execute(
        'CREATE UNIQUE INDEX uq_only_one_open_session ON activity_log(1) WHERE ended_at IS NULL',
      );
      legacy.execute('PRAGMA user_version = 32');
      legacy.dispose();

      final upgraded = DatabaseImpl(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(
        (await upgraded.activityDao.getActivityLogById(1)).startedAt,
        1000,
      );
      await upgraded.activityDao.insertActivityLog(
        ActivityLogCompanion.insert(activityId: 1, startedAt: 2000),
      );
      expect(await upgraded.select(upgraded.activityLog).get(), hasLength(2));
      expect(await upgraded.select(upgraded.activitySchedule).get(), isEmpty);
      expect(await upgraded.select(upgraded.activityOccurrence).get(), isEmpty);
      final integrity = await upgraded
          .customSelect('PRAGMA foreign_key_check')
          .get();
      expect(integrity, isEmpty);
    },
  );
}
