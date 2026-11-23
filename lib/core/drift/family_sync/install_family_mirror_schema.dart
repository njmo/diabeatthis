import '../../../common/family_sync/family_mirror_integration.dart';
import '../database_impl.dart';

// Export only the inputs to the shared progress state machine.
String _mealAddOnProgress(String prefix) {
  final context = '${prefix}add_on_bolus_context';
  return """
    CASE WHEN ${prefix}status IN ('eating-extra', 'waiting-for-bolus')
      AND json_valid($context) THEN
      CASE WHEN json_extract($context, '\$.version') = 1
        AND json_type($context, '\$.originalStatus') = 'text'
        AND json_type($context, '\$.awaitingBolus') IN ('true', 'false')
      THEN json_object(
        'originalStatus', json_extract($context, '\$.originalStatus'),
        'awaitingBolus', json_extract($context, '\$.awaitingBolus') = 1
          OR (coalesce(json_extract($context, '\$.requestedExtendedCarbs'), 0) > 0
            AND coalesce(json_extract($context, '\$.extendedCarbsConfirmed'), 0) = 0),
        'additionalServing', json_extract($context, '\$.additionalServing'),
        'bolusBeforeExtra', coalesce(json_extract($context, '\$.bolusBeforeExtra'),
          coalesce(json_array_length($context, '\$.acceptedWizardKeys'), 0) > 0)
      ) END
    END
    """;
}

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
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS family_sync_header_completion (source_id TEXT PRIMARY KEY, completed INTEGER NOT NULL DEFAULT 0, retry_after INTEGER NOT NULL DEFAULT 0)',
  );
  await db.customStatement(
    'INSERT OR IGNORE INTO family_sync_header_completion(source_id) SELECT source_id FROM family_sync_identity WHERE owner_uid IS NOT NULL',
  );
  await db.customStatement(
    '''CREATE TABLE IF NOT EXISTS family_plan_journal (
    operation_id TEXT PRIMARY KEY, claim_token TEXT NOT NULL, owner_uid TEXT NOT NULL, source_id TEXT NOT NULL,
    outcome TEXT NOT NULL, reason TEXT, result_id INTEGER,
    required_revisions TEXT NOT NULL, cancel_occurrence_id INTEGER, notification_cleared INTEGER NOT NULL DEFAULT 0, result_bound INTEGER NOT NULL DEFAULT 0, acknowledged INTEGER NOT NULL DEFAULT 0)''',
  );
  await db.customStatement(
    "CREATE TABLE IF NOT EXISTS family_cloud_connection(singleton INTEGER PRIMARY KEY CHECK(singleton=1),owner_uid TEXT,state TEXT NOT NULL DEFAULT 'connecting',updated_at INTEGER NOT NULL DEFAULT 0)",
  );
  await db.customStatement(
    'INSERT OR IGNORE INTO family_cloud_connection(singleton) VALUES(1)',
  );
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS family_plan_submissions(owner_uid TEXT PRIMARY KEY,payload TEXT NOT NULL)',
  );
  await db.customStatement('''CREATE TABLE IF NOT EXISTS family_workflow_lock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,kind TEXT NOT NULL,entity_id INTEGER NOT NULL,
    phase TEXT NOT NULL,active INTEGER NOT NULL,updated_at INTEGER NOT NULL,
    UNIQUE(kind,entity_id))''');
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS family_plan_notification_cancellations(operation_id TEXT NOT NULL,occurrence_id INTEGER NOT NULL,cleared INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(operation_id,occurrence_id))',
  );
  for (final integration in familyMirrorIntegrations) {
    final table = integration.table;
    final mealTrigger = table == 'meal'
        ? await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE type='trigger' AND name='family_sync_meal_update'",
              )
              .getSingleOrNull()
        : null;
    final upgradeMealExport =
        mealTrigger != null &&
        !mealTrigger.read<String>('sql').contains("'treatment_surplus'");
    String key(String prefix) => integration.keys
        .map((key) => 'CAST($prefix"$key" AS TEXT)')
        .join(" || '_' || ");
    String payload(String prefix) {
      String encode(Iterable<String> columns) =>
          "json_object(${columns.map((column) => "'$column', $prefix\"$column\"").join(', ')})";
      final columns = integration.columns;
      if (table != 'meal') return encode(columns);
      final timedColumns = columns.where((column) => column != 'planned_day');
      final base =
          'CASE WHEN ${prefix}planned_day IS NULL THEN ${encode(timedColumns)} '
          'ELSE ${encode(columns)} END';
      // json_patch omits the optional field when there is no relevant context.
      return "json_patch($base, json_object('add_on_progress', ${_mealAddOnProgress(prefix)} || '', "
          "'treatment_surplus', nullif(${prefix}treatment_surplus, 0)))";
    }

    for (final event in ['INSERT', 'UPDATE', 'DELETE']) {
      final deleted = event == 'DELETE';
      final prefix = deleted ? 'OLD.' : 'NEW.';
      final differences = [
        for (final column in integration.columns)
          'OLD."$column" IS NOT NEW."$column"',
        if (table == 'meal')
          '(${_mealAddOnProgress('OLD.')}) IS NOT (${_mealAddOnProgress('NEW.')})',
        if (table == 'meal')
          'OLD.treatment_surplus IS NOT NEW.treatment_surplus',
      ];
      final condition = event == 'UPDATE'
          ? 'WHEN ${differences.join(' OR ')}'
          : '';
      if (upgradeMealExport) {
        await db.customStatement(
          'DROP TRIGGER IF EXISTS family_sync_meal_${event.toLowerCase()}',
        );
      }
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS family_sync_${table}_${event.toLowerCase()}
        AFTER $event ON "$table" $condition BEGIN
        INSERT INTO family_sync_outbox(kind,entity_id,revision,deleted,payload)
        VALUES('${integration.kind}',${key(prefix)},1,${deleted ? 1 : 0},${deleted ? 'NULL' : payload(prefix)})
        ON CONFLICT(kind,entity_id) DO UPDATE SET revision=revision+1,deleted=excluded.deleted,payload=excluded.payload;
        END''',
      );
    }
    if (upgradeMealExport) {
      await db.customStatement("""
        INSERT INTO family_sync_outbox(kind,entity_id,revision,deleted,payload)
        SELECT 'meals', ${key('')},1,0,${payload('')} FROM meal
        WHERE (${_mealAddOnProgress('')}) IS NOT NULL OR treatment_surplus = 1
        ON CONFLICT(kind,entity_id) DO UPDATE SET
          revision=revision+1,deleted=0,payload=excluded.payload
        WHERE family_sync_outbox.payload IS NOT excluded.payload
        """);
    }
    // Existing databases need a complete first export, regardless of old flags.
    await db.customStatement(
      '''INSERT OR IGNORE INTO family_sync_outbox(kind,entity_id,revision,deleted,payload)
      SELECT '${integration.kind}',${key('')},1,0,${payload('')} FROM "$table"''',
    );
  }
}
