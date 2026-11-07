import 'package:drift/drift.dart';

import '../database_impl.dart';

/// Existing history is preserved; stable identity applies to new reschedules.
Future<void> migrateActivityRescheduling(
  DatabaseImpl db,
  Migrator migrator,
) async {
  await migrator.createTable(db.activityScheduleException);
  await migrator.createTable(db.activityOccurrenceReschedule);
}
