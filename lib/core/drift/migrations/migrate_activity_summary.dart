import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateActivitySummary(DatabaseImpl db, Migrator migrator) async {
  final columns = await db
      .customSelect('PRAGMA table_info(activity_log)')
      .get();
  final names = columns.map((row) => row.read<String>('name')).toSet();
  final addSummary = !names.contains('summarized_at');
  final addDismissal = !names.contains('summary_dismissed_at');
  if (addSummary) {
    await migrator.addColumn(db.activityLog, db.activityLog.summarizedAt);
  }
  if (addDismissal) {
    await migrator.addColumn(db.activityLog, db.activityLog.summaryDismissedAt);
  }
  if (!addSummary && !addDismissal) return;

  // Workflow backfills must preserve the history's sync status and timestamps.
  final triggers = await db
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = 'activity_log'",
      )
      .get();
  for (final trigger in triggers) {
    final name = trigger.read<String>('name').replaceAll('"', '""');
    await db.customStatement('DROP TRIGGER "$name"');
  }
  try {
    if (addSummary) {
      await db.customStatement(
        'UPDATE activity_log SET summarized_at = updated_at '
        'WHERE ended_at IS NOT NULL AND (intensity IS NOT NULL OR notes IS NOT NULL)',
      );
    }
    if (addDismissal) {
      // Existing history should not become a backlog of dashboard reminders.
      await db.customStatement(
        'UPDATE activity_log SET summary_dismissed_at = ended_at '
        'WHERE ended_at IS NOT NULL',
      );
    }
  } finally {
    for (final trigger in triggers) {
      await db.customStatement(trigger.read<String>('sql'));
    }
  }
}
