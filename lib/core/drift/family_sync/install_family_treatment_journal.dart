import '../database_impl.dart';

Future<void> installFamilyTreatmentJournal(DatabaseImpl db) async {
  await db.customStatement(
    '''CREATE TABLE IF NOT EXISTS family_treatment_journal (
      claim_id TEXT PRIMARY KEY, owner_uid TEXT NOT NULL,
      family_id TEXT NOT NULL, message_id TEXT NOT NULL,
      installation_id TEXT NOT NULL, proof TEXT NOT NULL,
      confirmed_at INTEGER, meal_id INTEGER, applied_at INTEGER, acknowledged INTEGER NOT NULL DEFAULT 0,
      ack_attempt_order INTEGER NOT NULL DEFAULT 0,
      actual_quantity REAL,
      authorization_epoch TEXT, account_off_generation INTEGER, family_off_generation INTEGER,
      cancelled INTEGER NOT NULL DEFAULT 0,
      UNIQUE(family_id,message_id,owner_uid))''',
  );
  Future<bool> hasColumn(String name) async =>
      (await db
              .customSelect('PRAGMA table_info(family_treatment_journal)')
              .get())
          .any((row) => row.read<String>('name') == name);
  for (final column in {
    'confirmed_at': 'INTEGER',
    'ack_attempt_order': 'INTEGER NOT NULL DEFAULT 0',
    'actual_quantity': 'REAL',
    'authorization_epoch': 'TEXT',
    'account_off_generation': 'INTEGER',
    'family_off_generation': 'INTEGER',
    'cancelled': 'INTEGER NOT NULL DEFAULT 0',
  }.entries) {
    if (await hasColumn(column.key)) continue;
    try {
      await db.customStatement(
        'ALTER TABLE family_treatment_journal ADD COLUMN ${column.key} ${column.value}',
      );
    } catch (_) {
      if (!await hasColumn(column.key)) rethrow;
    }
  }
}
