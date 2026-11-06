import '../../../common/family_sync/family_mirror_integration.dart';
import '../database_impl.dart';

/// Capture is transactional with domain writes, including writes by foreground.
/// Bookkeeping is independent of the legacy is_synced flags.
Future<void> installFamilyMirrorSchema(DatabaseImpl db) async {
  await db.customStatement(
    '''CREATE TABLE IF NOT EXISTS family_sync_identity (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1), source_id TEXT NOT NULL,
    owner_uid TEXT, enabled INTEGER NOT NULL DEFAULT 0, last_error TEXT, last_success INTEGER, enabled_revision INTEGER NOT NULL DEFAULT 0)''',
  );
  await db.customStatement(
    "INSERT OR IGNORE INTO family_sync_identity(singleton, source_id) VALUES(1, lower(hex(randomblob(16))))",
  );
  await db.customStatement(
    '''CREATE TABLE IF NOT EXISTS family_sync_outbox (
    kind TEXT NOT NULL, entity_id TEXT NOT NULL, revision INTEGER NOT NULL,
    acknowledged_revision INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0,
    payload TEXT, failed_revision INTEGER NOT NULL DEFAULT 0, last_error TEXT, PRIMARY KEY(kind,entity_id))''',
  );
  await db.customStatement(
    '''CREATE TABLE IF NOT EXISTS family_sync_runtime (
    singleton INTEGER PRIMARY KEY CHECK(singleton=1), active_until INTEGER NOT NULL DEFAULT 0, requested INTEGER NOT NULL DEFAULT 0)''',
  );
  await db.customStatement(
    'INSERT OR IGNORE INTO family_sync_runtime(singleton) VALUES(1)',
  );
  for (final integration in familyMirrorIntegrations) {
    final table = integration.table;
    String key(String prefix) => integration.keys
        .map((key) => 'CAST($prefix"$key" AS TEXT)')
        .join(" || '_' || ");
    String payload(String prefix) =>
        "json_object(${integration.columns.map((column) => "'$column', $prefix\"$column\"").join(', ')})";
    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      final deleted = event == 'DELETE';
      final prefix = deleted ? 'OLD.' : 'NEW.';
      final condition = event == 'UPDATE'
          ? 'WHEN ${integration.columns.map((column) => 'OLD."$column" IS NOT NEW."$column"').join(' OR ')}'
          : '';
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS family_sync_${table}_${event.toLowerCase()}
        AFTER $event ON "$table" $condition BEGIN
        INSERT INTO family_sync_outbox(kind,entity_id,revision,deleted,payload)
        VALUES('${integration.kind}',${key(prefix)},1,${deleted ? 1 : 0},${deleted ? 'NULL' : payload(prefix)})
        ON CONFLICT(kind,entity_id) DO UPDATE SET revision=revision+1,deleted=excluded.deleted,payload=excluded.payload;
        END''',
      );
    }
    // Existing databases need a complete first export, regardless of old flags.
    await db.customStatement(
      '''INSERT OR IGNORE INTO family_sync_outbox(kind,entity_id,revision,deleted,payload)
      SELECT '${integration.kind}',${key('')},1,0,${payload('')} FROM "$table"''',
    );
  }
}
