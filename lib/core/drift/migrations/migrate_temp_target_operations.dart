import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateTempTargetOperations(
  DatabaseImpl db,
  Migrator migrator,
) async {
  final existing =
      (await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type IN ('table', 'index', 'trigger')",
              )
              .get())
          .map((row) => row.read<String>('name'))
          .toSet();
  if (!existing.contains('temp_target_operation')) {
    await migrator.createTable(db.tempTargetOperation);
  }
  for (final index in [
    db.idxTempTargetOperationEntity,
    db.idxTempTargetOperationStatus,
  ]) {
    if (!existing.contains(index.entityName)) await migrator.createIndex(index);
  }
  for (final trigger in [
    db.tempTargetOperationActivityEnded,
    db.tempTargetOperationActivityDeleted,
  ]) {
    if (!existing.contains(trigger.entityName)) {
      await migrator.createTrigger(trigger);
    }
  }
}
