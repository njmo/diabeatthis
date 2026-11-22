import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';

/// Only confirmed send intents, not a caregiver copy of patient domain tables.
class FamilyPlanSubmissionStore {
  const FamilyPlanSubmissionStore(DatabaseImpl db)
    : _db = db,
      _open = null;
  const FamilyPlanSubmissionStore.lazy(DatabaseImpl Function() open)
    : _db = null,
      _open = open;

  final DatabaseImpl? _db;
  final DatabaseImpl Function()? _open;
  DatabaseImpl get db => _db ?? _open!();
  Future<Map<String, dynamic>?> pending(String uid) async {
    final row = await db
        .customSelect(
          'SELECT payload FROM family_plan_submissions WHERE owner_uid=?',
          variables: [Variable(uid)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          );
  }

  Future<Map<String, dynamic>> reserve(
    String uid,
    Map<String, dynamic> payload,
  ) => db.transaction(() async {
    final old = await pending(uid);
    if (old != null) {
      final a = {...old}..remove('id');
      final b = {...payload}..remove('id');
      if (jsonEncode(a) != jsonEncode(b)) {
        throw StateError('A previous send must be resolved first');
      }
      return old;
    }
    await db.customStatement(
      'INSERT INTO family_plan_submissions(owner_uid,payload) VALUES(?,?)',
      [uid, jsonEncode(payload)],
    );
    return payload;
  });
  Future<void> clear(String uid, String id) => db.customStatement(
    "DELETE FROM family_plan_submissions WHERE owner_uid=? AND json_extract(payload,'\$.id')=?",
    [uid, id],
  );
}
