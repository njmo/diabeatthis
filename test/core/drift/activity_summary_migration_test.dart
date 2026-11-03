import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version41SummaryDatabase extends DatabaseImpl {
  Version41SummaryDatabase(super.executor);
  @override
  int get schemaVersion => 41;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'ALTER TABLE activity_log DROP COLUMN summarized_at',
      );
      await customStatement(
        'ALTER TABLE activity_log DROP COLUMN summary_dismissed_at',
      );
    },
  );
}

void main() {
  test(
    'migration preserves legacy details and sync metadata, then persists new workflow across restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'activity-summary-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version41SummaryDatabase(NativeDatabase(file));
      await old.customStatement(
        "INSERT INTO activity (id, name, percentage_pre, percentage_post) VALUES (1, 'Running', 80, 80)",
      );
      await old.customStatement(
        "INSERT INTO activity_log (id, activity_id, started_at, ended_at, intensity, notes, is_synced, updated_at) VALUES (1, 1, 1000, 2000, 'high', 'Legacy', 1, 3000)",
      );
      await old.customStatement(
        'INSERT INTO activity_log (id, activity_id, started_at) VALUES (2, 1, 4000)',
      );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      final migrated = await db.activityDao.getActivityLogById(1);
      expect(migrated.notes, 'Legacy');
      expect(migrated.summarizedAt, 3000);
      expect(migrated.summaryDismissedAt, 2000);
      expect(migrated.updatedAt, 3000);
      expect(migrated.isSynced, isTrue);
      expect(
        await db.activityDao.watchCompletedActivitySummaries().first,
        isEmpty,
      );
      await db.activityDao.finishActivityLogIfOpen(
        2,
        DateTime.fromMillisecondsSinceEpoch(4000),
        DateTime.fromMillisecondsSinceEpoch(5000),
      );
      await db.activityDao.updateCompletedActivitySummary(
        id: 2,
        intensity: 'light',
        notes: 'New summary',
      );
      expect((await db.activityDao.getActivityLogById(2)).isSynced, isFalse);
      await db.close();
      final reopened = DatabaseImpl(NativeDatabase(file));
      addTearDown(reopened.close);
      final entries = await reopened.activityDao
          .watchCompletedActivitySummaries()
          .first;
      expect(entries.single.log.id, 2);
      expect(entries.single.log.summarizedAt, isNotNull);
      await reopened.activityDao.dismissActivitySummary(2);
      expect(
        await reopened.activityDao.watchCompletedActivitySummaries().first,
        isEmpty,
      );
    },
  );
}
