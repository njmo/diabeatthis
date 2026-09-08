import 'package:drift/drift.dart';

import '../database_impl.dart';

/// Version 15 existed with either the generic event table or the stress table.
Future<void> migrateStressEvents(DatabaseImpl db, Migrator migrator) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('health_event', 'stress_event')",
      )
      .get();
  final tables = rows.map((row) => row.read<String>('name')).toSet();
  if (!tables.contains('stress_event')) {
    await migrator.createTable(db.stressEvent);
    await migrator.createIndex(db.idxStressEventOccurredAt);
  }
  if (tables.contains('health_event')) {
    // Keep the legacy table intact, including event types no longer offered.
    await db.customStatement('''
      INSERT INTO stress_event
        (source, external_id, notes, ended_at, stress_level, occurred_at, recorded_at)
      SELECT source, external_id, notes, ended_at, stress_level, occurred_at, recorded_at
      FROM health_event WHERE type = 'stress'
      ON CONFLICT (source, external_id) DO NOTHING
    ''');
  }
}
