import 'dart:io';

import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_proposal.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:drift/drift.dart' show MigrationStrategy, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version35TempTargetDatabase extends DatabaseImpl {
  Version35TempTargetDatabase(super.executor);

  @override
  int get schemaVersion => 35;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        'DROP TRIGGER temp_target_operation_activity_ended',
      );
      await customStatement(
        'DROP TRIGGER temp_target_operation_activity_deleted',
      );
      await customStatement('DROP TABLE temp_target_operation');
    },
  );
}

void main() {
  test(
    'version 35 upgrade retains activity history and installs durable target closure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'temp-target-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version35TempTargetDatabase(NativeDatabase(file));
      final activityId = await old
          .into(old.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Run',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      final logId = await old
          .into(old.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: 1000,
            ),
          );
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final repository = TempTargetOperationRepository(db);
      final now = DateTime.utc(2026, 10, 29, 12);
      final operation = await repository.createOffer(
        TempTargetProposal(
          id: 'migration-offer',
          entityId: logId,
          targetType: 'activity',
          target: 140,
          durationMinutes: 90,
          expiresAt: now.add(const Duration(minutes: 5)),
          source: 'https://nightscout.example',
        ),
        now: now,
      );
      expect(operation.status, TempTargetOperationStatus.pendingDelivery);
      expect((await db.select(db.activityLog).get()).single.startedAt, 1000);
      await (db.update(db.activityLog)..where((row) => row.id.equals(logId)))
          .write(const ActivityLogCompanion(endedAt: Value(2000)));
      expect(
        (await repository.get(
          'migration-offer',
        ))!.closedAt!.millisecondsSinceEpoch,
        2000,
      );
      final openLogId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activityId,
              startedAt: 3000,
            ),
          );
      await repository.createOffer(
        TempTargetProposal(
          id: 'deleted-after-migration',
          entityId: openLogId,
          targetType: 'activity',
          target: 140,
          durationMinutes: 90,
          expiresAt: now.add(const Duration(minutes: 5)),
          source: 'https://nightscout.example',
        ),
        now: now,
      );
      await (db.delete(
        db.activityLog,
      )..where((row) => row.id.equals(openLogId))).go();
      expect(
        (await repository.get('deleted-after-migration'))!.closedAt,
        isNotNull,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_temp_target_operation_%'",
          )
          .get();
      expect(indexes, hasLength(2));
    },
  );
}
