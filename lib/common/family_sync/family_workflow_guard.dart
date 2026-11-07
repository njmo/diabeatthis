import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/database_impl.dart';
import 'family_workflow_phase.dart';

final familyWorkflowGuardProvider = Provider<FamilyWorkflowGuard>(
  (ref) => FamilyWorkflowGuard(),
);

/// Synchronous protection in the child runner, plus a small cloud-visible state.
class FamilyWorkflowGuard {
  FamilyWorkflowGuard([this.database]);
  DatabaseImpl? database;
  void attach(DatabaseImpl db) {
    database = db;
  }

  final blocked = <String, int>{};
  Future<void> writes = Future<void>.value();
  bool contains(String kind, int id) => blocked[kind] == id;
  void record(String kind, int? id, String phase) {
    if (['initializing', 'unavailable'].contains(phase)) return;
    final active = familyWorkflowPhaseBlocks(kind, phase);
    if (id != null && active) {
      blocked[kind] = id;
    } else {
      blocked.remove(kind);
    }
    final db = database;
    if (db == null) return;
    writes = writes
        .then(
          (_) => db.transaction(() async {
            await db.customStatement(
              'UPDATE family_workflow_lock SET active=0,updated_at=? WHERE kind=? AND active=1 AND (? IS NULL OR entity_id<>?)',
              [DateTime.now().millisecondsSinceEpoch, kind, id, id],
            );
            if (id != null) {
              await db.customStatement(
                "INSERT INTO family_workflow_lock(kind,entity_id,phase,active,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(kind,entity_id) DO UPDATE SET phase=excluded.phase,active=CASE WHEN excluded.kind='meal' AND excluded.phase='planned' THEN MAX(family_workflow_lock.active,excluded.active) ELSE excluded.active END,updated_at=excluded.updated_at",
                [
                  kind,
                  id,
                  phase,
                  active ? 1 : 0,
                  DateTime.now().millisecondsSinceEpoch,
                ],
              );
            }
          }),
        )
        .catchError((Object error) {
          /* Live guard remains active if optional projection fails. */
        });
  }

  Future<bool> persisted(String kind, int id) =>
      persistedBlock(kind, entityId: id);
  Future<bool> persistedAny(String kind) => persistedBlock(kind);
  Future<bool> persistedBlock(String kind, {int? entityId}) async {
    final db = database;
    if (db == null) return false;
    return (await db
            .customSelect(
              "SELECT id FROM family_workflow_lock WHERE kind=? AND (? IS NULL OR entity_id=?) AND active=1 AND (kind<>'activity' OR phase<>'planned') LIMIT 1",
              variables: [
                Variable(kind),
                Variable<int>(entityId),
                Variable<int>(entityId),
              ],
            )
            .get())
        .isNotEmpty;
  }
}
