import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../common/family_sync/family_mirror_record.dart';
import '../database_impl.dart';

class FamilyMirrorOutbox {
  const FamilyMirrorOutbox(this.db);
  final DatabaseImpl db;
  Future<String> sourceForOwner(String uid) async {
    final row = await db
        .customSelect('SELECT * FROM family_sync_identity WHERE singleton=1')
        .getSingle();
    final owner = row.readNullable<String>('owner_uid');
    if (owner != null && owner != uid) {
      throw StateError(
        'The local database belongs to a different family account',
      );
    }
    return row.read<String>('source_id');
  }

  Future<String> bindOwner(String uid) => db.transaction(() async {
    final row = await db
        .customSelect('SELECT * FROM family_sync_identity WHERE singleton=1')
        .getSingle();
    final current = row.readNullable<String>('owner_uid');
    if (current != null && current != uid) {
      throw StateError(
        'The local database belongs to a different family account',
      );
    }
    if (current == null) {
      await db.customStatement(
        'UPDATE family_sync_identity SET owner_uid=? WHERE singleton=1',
        [uid],
      );
    }
    return row.read<String>('source_id');
  });
  Future<List<FamilyMirrorRecord>> pending({int limit = 25}) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM family_sync_outbox WHERE revision>acknowledged_revision AND failed_revision<>revision ORDER BY kind,entity_id LIMIT ?',
          variables: [Variable(limit)],
        )
        .get();
    return rows
        .map(
          (row) => FamilyMirrorRecord(
            kind: row.read<String>('kind'),
            id: row.read<String>('entity_id'),
            revision: row.read<int>('revision'),
            deleted: row.read<int>('deleted') == 1,
            payload: row.readNullable<String>('payload') == null
                ? null
                : jsonDecode(row.read<String>('payload'))
                      as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> reject(FamilyMirrorRecord record) => db.customStatement(
    'UPDATE family_sync_outbox SET failed_revision=?,last_error=? WHERE kind=? AND entity_id=? AND revision=?',
    [
      record.revision,
      'invalid-mirror-record',
      record.kind,
      record.id,
      record.revision,
    ],
  );
  Future<bool> enabledAt(int revision) async {
    final settings = await db
        .customSelect(
          'SELECT enabled,enabled_revision FROM family_sync_identity WHERE singleton=1',
        )
        .getSingle();
    return settings.read<int>('enabled') == 1 &&
        settings.read<int>('enabled_revision') == revision;
  }

  Future<void> acknowledge(
    String uid,
    String sourceId,
    List<FamilyMirrorRecord> records,
  ) => db.transaction(() async {
    final identity = await db
        .customSelect('SELECT * FROM family_sync_identity WHERE singleton=1')
        .getSingle();
    if (identity.readNullable<String>('owner_uid') != uid ||
        identity.read<String>('source_id') != sourceId) {
      throw StateError('Sync acknowledgement belongs to another source');
    }
    for (final record in records) {
      await db.customStatement(
        'UPDATE family_sync_outbox SET acknowledged_revision=? WHERE kind=? AND entity_id=? AND revision=?',
        [record.revision, record.kind, record.id, record.revision],
      );
    }
  });
}
