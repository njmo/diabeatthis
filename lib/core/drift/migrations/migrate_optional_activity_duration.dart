import 'package:drift/drift.dart';

import '../database_impl.dart';

/// Preserve existing durations, identifiers and links while allowing sessions
/// whose end is recorded manually, for both one-off and recurring activities.
Future<void> migrateOptionalActivityDuration(
  DatabaseImpl db,
  Migrator migrator,
) async {
  await migrator.alterTable(
    // ignore: experimental_member_use
    TableMigration(db.activitySchedule),
  );
  await migrator.alterTable(
    // ignore: experimental_member_use
    TableMigration(db.activityOccurrence),
  );
}
