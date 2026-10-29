import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../../common/events/data/notification/temp_target_type.dart';
import '../../../../common/temporary_targets/owned_temp_target.dart';
import '../../../../common/temporary_targets/temp_target_operation.dart';
import '../../../../common/temporary_targets/temp_target_proposal.dart';
import '../../../drift/database_impl.dart' hide TempTargetOperation;

/// SQLite is authoritative for consent, attempted requests and target ownership.
class TempTargetOperationRepository {
  const TempTargetOperationRepository(this.db);

  final DatabaseImpl db;

  Future<TempTargetOperation?> get(String requestId) async {
    final row = await (db.select(
      db.tempTargetOperation,
    )..where((table) => table.requestId.equals(requestId))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<TempTargetOperation>> list({
    Set<TempTargetOperationStatus>? statuses,
    TempTargetOperationKind? kind,
  }) async {
    final query = db.select(db.tempTargetOperation)
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
        (table) => OrderingTerm.desc(table.rowId),
      ]);
    if (statuses != null) {
      query.where((table) => table.status.isIn(statuses.map((e) => e.name)));
    }
    if (kind != null) query.where((table) => table.kind.equals(kind.name));
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  /// A repeat does not replace consent, delivery or attempt information.
  Future<TempTargetOperation> createOffer(
    TempTargetProposal proposal, {
    DateTime? now,
  }) async {
    final time = now ?? clock.now();
    _validateIdentity(proposal.id, proposal.source);
    await db
        .into(db.tempTargetOperation)
        .insert(
          TempTargetOperationCompanion.insert(
            requestId: proposal.id,
            kind: TempTargetOperationKind.start.name,
            entityId: proposal.entityId,
            targetType: proposal.targetType,
            source: proposal.source,
            status: TempTargetOperationStatus.pendingDelivery.name,
            payloadJson: jsonEncode({'proposal': proposal.toJson()}),
            createdAt: time.millisecondsSinceEpoch,
            updatedAt: time.millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await get(proposal.id))!;
  }

  Future<TempTargetOperation?> latestStart({
    required int entityId,
    required String source,
    String? targetType,
  }) async {
    final query = db.select(db.tempTargetOperation)
      ..where(
        (table) =>
            table.kind.equals(TempTargetOperationKind.start.name) &
            table.entityId.equals(entityId) &
            table.source.equals(source),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
        (table) => OrderingTerm.desc(table.rowId),
      ])
      ..limit(1);
    if (targetType != null) {
      query.where((table) => table.targetType.equals(targetType));
    }
    final row = await query.getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// Call only after the platform has successfully displayed the notification.
  Future<bool> markDelivered(String requestId, {DateTime? now}) async {
    final time = now ?? clock.now();
    return await (db.update(db.tempTargetOperation)..where(
              (table) =>
                  table.requestId.equals(requestId) &
                  table.status.equals(
                    TempTargetOperationStatus.pendingDelivery.name,
                  ),
            ))
            .write(
              TempTargetOperationCompanion(
                status: Value(TempTargetOperationStatus.awaitingConsent.name),
                deliveredAt: Value(time.millisecondsSinceEpoch),
                updatedAt: Value(time.millisecondsSinceEpoch),
              ),
            ) ==
        1;
  }

  Future<bool> decline(String requestId, {DateTime? now}) => _transition(
    requestId,
    from: {
      TempTargetOperationStatus.pendingDelivery,
      TempTargetOperationStatus.awaitingConsent,
    },
    to: TempTargetOperationStatus.declined,
    now: now,
  );

  /// A transient serialization conflict consumes no write authorization. Ask
  /// again through the normal delivery path rather than reusing the approval.
  Future<bool> deferConsent(String requestId, {DateTime? now}) async =>
      await (db.update(db.tempTargetOperation)..where(
            (table) =>
                table.requestId.equals(requestId) &
                table.kind.equals(TempTargetOperationKind.start.name) &
                table.closedAt.isNull() &
                table.status.isIn([
                  TempTargetOperationStatus.pendingDelivery.name,
                  TempTargetOperationStatus.awaitingConsent.name,
                ]),
          ))
          .write(
            TempTargetOperationCompanion(
              status: Value(TempTargetOperationStatus.pendingDelivery.name),
              deliveredAt: const Value(null),
              updatedAt: Value((now ?? clock.now()).millisecondsSinceEpoch),
            ),
          ) ==
      1;

  /// Claims consent and stores the exact attempted treatment before HTTP starts.
  Future<bool> claimStart(
    String requestId,
    OwnedTempTarget attempted, {
    DateTime? now,
  }) => db.transaction(() async {
    final operation = await get(requestId);
    if (operation == null || operation.kind != TempTargetOperationKind.start) {
      return false;
    }
    if (operation.closedAt != null) return false;
    if (operation.targetType == TempTargetType.activity) {
      final log = await db.activityDao.getActivityLogByIdOrNull(
        operation.entityId,
      );
      if (log == null || log.endedAt != null) return false;
    } else if (operation.targetType == TempTargetType.meal) {
      final meal = await db.mealDao.getMealById(operation.entityId);
      if (meal == null || meal.status != 'planned') return false;
    } else {
      return false;
    }
    _validateTarget(operation, attempted);
    return _claim(operation, attemptedTarget: attempted, now: now);
  });

  Future<TempTargetOperation> createStop({
    required String requestId,
    required OwnedTempTarget owned,
    required DateTime stoppedAt,
    DateTime? now,
  }) async {
    final time = now ?? clock.now();
    _validateIdentity(requestId, owned.source);
    await db
        .into(db.tempTargetOperation)
        .insert(
          TempTargetOperationCompanion.insert(
            requestId: requestId,
            kind: TempTargetOperationKind.stop.name,
            entityId: owned.entityId,
            targetType: owned.targetType,
            source: owned.source,
            status: TempTargetOperationStatus.pendingDelivery.name,
            payloadJson: jsonEncode({
              'attemptedTarget': owned.toJson(),
              'stoppedAt': stoppedAt.toUtc().toIso8601String(),
            }),
            createdAt: time.millisecondsSinceEpoch,
            updatedAt: time.millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await get(requestId))!;
  }

  Future<bool> claimStop(String requestId, {DateTime? now}) =>
      db.transaction(() async {
        final operation = await get(requestId);
        if (operation == null ||
            operation.kind != TempTargetOperationKind.stop ||
            operation.attemptedTarget == null ||
            operation.stoppedAt == null) {
          return false;
        }
        return _claim(operation, now: now);
      });

  Future<bool> _claim(
    TempTargetOperation operation, {
    OwnedTempTarget? attemptedTarget,
    DateTime? now,
  }) async {
    if ((await unresolvedSends()).any(
      (e) => e.requestId != operation.requestId && e.source == operation.source,
    )) {
      return false;
    }
    final attemptAt = attemptedTarget?.startedAt ?? operation.stoppedAt;
    final previousAttempts = await _attempts(operation.source);
    if (attemptAt == null ||
        previousAttempts.any(
          (e) =>
              e.requestId != operation.requestId &&
              attemptAt.difference(_attemptAt(e)!).abs() <
                  const Duration(seconds: 1),
        )) {
      return false;
    }
    final payload = operation.payloadToJson();
    if (attemptedTarget != null) {
      payload['attemptedTarget'] = attemptedTarget.toJson();
    }
    return await (db.update(db.tempTargetOperation)..where(
              (table) =>
                  table.requestId.equals(operation.requestId) &
                  table.status.isIn([
                    TempTargetOperationStatus.pendingDelivery.name,
                    TempTargetOperationStatus.awaitingConsent.name,
                  ]),
            ))
            .write(
              TempTargetOperationCompanion(
                status: Value(TempTargetOperationStatus.sending.name),
                payloadJson: Value(jsonEncode(payload)),
                updatedAt: Value((now ?? clock.now()).millisecondsSinceEpoch),
              ),
            ) ==
        1;
  }

  /// Confirms delivery and changes ownership in the same transaction.
  Future<bool> markSent(
    String requestId, {
    OwnedTempTarget? confirmed,
    DateTime? now,
  }) => db.transaction(() async {
    final operation = await get(requestId);
    if (operation == null ||
        !{
          TempTargetOperationStatus.sending,
          TempTargetOperationStatus.unknownResult,
        }.contains(operation.status)) {
      return false;
    }
    final time = now ?? clock.now();
    final payload = operation.payloadToJson();
    var status = TempTargetOperationStatus.sent;
    if (operation.kind == TempTargetOperationKind.start) {
      final target = confirmed ?? operation.attemptedTarget;
      if (target == null) throw StateError('Start attempt is missing');
      _validateTarget(operation, target);
      if (operation.attemptedTarget == null ||
          !_sameTarget(operation.attemptedTarget!, target)) {
        throw ArgumentError('Confirmed target does not match the attempt');
      }
      payload['confirmedTarget'] = target.toJson();
      final starts = await list(kind: TempTargetOperationKind.start);
      // A delayed reconciliation must not restore an older target as current.
      if (starts.any(
        (e) =>
            e.requestId != requestId &&
            e.source == operation.source &&
            e.confirmedTarget != null &&
            e.confirmedTarget!.startedAt.isAfter(target.startedAt),
      )) {
        status = TempTargetOperationStatus.superseded;
      } else {
        for (final previous in starts.where(
          (e) =>
              e.requestId != requestId &&
              e.source == operation.source &&
              e.status == TempTargetOperationStatus.sent,
        )) {
          await _transition(
            previous.requestId,
            from: {TempTargetOperationStatus.sent},
            to: TempTargetOperationStatus.superseded,
            now: time,
          );
        }
      }
    } else {
      final owner = operation.attemptedTarget;
      if (owner == null) throw StateError('Stop ownership is missing');
      await completeOwned(owner, now: time);
    }
    return await (db.update(
          db.tempTargetOperation,
        )..where((table) => table.requestId.equals(requestId))).write(
          TempTargetOperationCompanion(
            status: Value(status.name),
            payloadJson: Value(jsonEncode(payload)),
            updatedAt: Value(time.millisecondsSinceEpoch),
          ),
        ) ==
        1;
  });

  Future<bool> markRejected(String requestId, {DateTime? now}) => _transition(
    requestId,
    from: {
      TempTargetOperationStatus.sending,
      TempTargetOperationStatus.unknownResult,
    },
    to: TempTargetOperationStatus.rejected,
    now: now,
  );

  Future<bool> markUnknownResult(String requestId, {DateTime? now}) =>
      _transition(
        requestId,
        from: {TempTargetOperationStatus.sending},
        to: TempTargetOperationStatus.unknownResult,
        now: now,
      );

  /// Ends an unresolved operation only after reconciliation proves it expired.
  Future<bool> completeOperation(String requestId, {DateTime? now}) =>
      db.transaction(() async {
        final operation = await get(requestId);
        if (operation == null ||
            !{
              TempTargetOperationStatus.sending,
              TempTargetOperationStatus.unknownResult,
            }.contains(operation.status)) {
          return false;
        }
        final changed = await _transition(
          requestId,
          from: {
            TempTargetOperationStatus.sending,
            TempTargetOperationStatus.unknownResult,
          },
          to: TempTargetOperationStatus.completed,
          now: now,
        );
        if (changed &&
            operation.kind == TempTargetOperationKind.stop &&
            operation.attemptedTarget != null) {
          await completeOwned(operation.attemptedTarget!, now: now);
        }
        return changed;
      });

  Future<List<TempTargetOperation>> unresolvedSends() => list(
    statuses: {
      TempTargetOperationStatus.sending,
      TempTargetOperationStatus.unknownResult,
    },
  );

  Future<TempTargetOperation?> latestOwnedOperation({String? source}) async {
    final starts = await list(
      kind: TempTargetOperationKind.start,
      statuses: {TempTargetOperationStatus.sent},
    );
    return starts
        .where(
          (e) =>
              e.confirmedTarget != null &&
              (source == null || e.source == source),
        )
        .firstOrNull;
  }

  Future<OwnedTempTarget?> latestOwned({String? source}) async =>
      (await latestOwnedOperation(source: source))?.confirmedTarget;

  Future<DateTime?> latestAttemptedStartAt() async {
    final starts = await list(kind: TempTargetOperationKind.start);
    final times =
        starts.map((e) => e.attemptedTarget?.startedAt).nonNulls.toList()
          ..sort();
    return times.lastOrNull;
  }

  Future<DateTime?> latestAttemptAt(String source) async {
    final operations = await _attempts(source);
    final times = operations.map(_attemptAt).nonNulls.toList()..sort();
    return times.lastOrNull;
  }

  DateTime? _attemptAt(TempTargetOperation operation) =>
      operation.kind == TempTargetOperationKind.stop
      ? operation.stoppedAt
      : operation.attemptedTarget?.startedAt;

  Future<List<TempTargetOperation>> _attempts(String source) async {
    final operations = await list(
      statuses: {
        TempTargetOperationStatus.sending,
        TempTargetOperationStatus.sent,
        TempTargetOperationStatus.unknownResult,
        TempTargetOperationStatus.completed,
        TempTargetOperationStatus.superseded,
      },
    );
    return operations
        .where((e) => e.source == source && _attemptAt(e) != null)
        .toList(growable: false);
  }

  Future<bool> closeActivity(int entityId, DateTime at) async =>
      await (db.update(db.tempTargetOperation)..where(
            (table) =>
                table.kind.equals(TempTargetOperationKind.start.name) &
                table.targetType.equals('activity') &
                table.entityId.equals(entityId) &
                table.closedAt.isNull(),
          ))
          .write(
            TempTargetOperationCompanion(
              closedAt: Value(at.millisecondsSinceEpoch),
            ),
          ) >
      0;

  Future<bool> completeOwned(OwnedTempTarget owned, {DateTime? now}) =>
      db.transaction(() async {
        final starts = await list(
          kind: TempTargetOperationKind.start,
          statuses: {TempTargetOperationStatus.sent},
        );
        var changed = false;
        for (final operation in starts) {
          if (operation.confirmedTarget != null &&
              _sameTarget(operation.confirmedTarget!, owned)) {
            changed =
                await _transition(
                  operation.requestId,
                  from: {TempTargetOperationStatus.sent},
                  to: TempTargetOperationStatus.completed,
                  now: now,
                ) ||
                changed;
          }
        }
        return changed;
      });

  /// Imports the previous preferences record without resurrecting old ownership.
  Future<void> importConfirmedOwned(
    OwnedTempTarget owned, {
    DateTime? now,
  }) => db.transaction(() async {
    final requestId =
        'legacy-owned-${Uri.encodeComponent(owned.source)}-${owned.startedAt.millisecondsSinceEpoch}';
    if (await get(requestId) != null) return;
    final starts = await list(kind: TempTargetOperationKind.start);
    if (starts.any(
      (e) =>
          e.source == owned.source &&
          e.confirmedTarget != null &&
          !e.confirmedTarget!.startedAt.isBefore(owned.startedAt),
    )) {
      return;
    }
    final time = now ?? clock.now();
    for (final previous in starts.where(
      (e) =>
          e.source == owned.source &&
          e.status == TempTargetOperationStatus.sent,
    )) {
      await _transition(
        previous.requestId,
        from: {TempTargetOperationStatus.sent},
        to: TempTargetOperationStatus.superseded,
        now: time,
      );
    }
    await db
        .into(db.tempTargetOperation)
        .insert(
          TempTargetOperationCompanion.insert(
            requestId: requestId,
            kind: TempTargetOperationKind.start.name,
            entityId: owned.entityId,
            targetType: owned.targetType,
            source: owned.source,
            status: TempTargetOperationStatus.sent.name,
            payloadJson: jsonEncode({
              'attemptedTarget': owned.toJson(),
              'confirmedTarget': owned.toJson(),
            }),
            createdAt: owned.startedAt.millisecondsSinceEpoch,
            updatedAt: time.millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  });

  Future<bool> _transition(
    String requestId, {
    required Set<TempTargetOperationStatus> from,
    required TempTargetOperationStatus to,
    DateTime? now,
  }) async =>
      await (db.update(db.tempTargetOperation)..where(
            (table) =>
                table.requestId.equals(requestId) &
                table.status.isIn(from.map((e) => e.name)),
          ))
          .write(
            TempTargetOperationCompanion(
              status: Value(to.name),
              updatedAt: Value((now ?? clock.now()).millisecondsSinceEpoch),
            ),
          ) ==
      1;

  void _validateIdentity(String requestId, String source) {
    if (requestId.trim().isEmpty || source.trim().isEmpty) {
      throw ArgumentError('Request ID and source must not be empty');
    }
  }

  void _validateTarget(TempTargetOperation operation, OwnedTempTarget target) {
    if (target.entityId != operation.entityId ||
        target.targetType != operation.targetType ||
        target.source != operation.source ||
        target.durationMinutes <= 0 ||
        !target.until.isAfter(target.startedAt)) {
      throw ArgumentError('Target does not match its operation');
    }
  }

  bool _sameTarget(OwnedTempTarget first, OwnedTempTarget second) =>
      first.entityId == second.entityId &&
      first.source == second.source &&
      first.targetType == second.targetType &&
      first.startedAt.millisecondsSinceEpoch ==
          second.startedAt.millisecondsSinceEpoch &&
      first.target == second.target &&
      first.durationMinutes == second.durationMinutes;

  TempTargetOperation _toDomain(TempTargetOperationData row) {
    final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
    return TempTargetOperation(
      requestId: row.requestId,
      kind: TempTargetOperationKind.values.byName(row.kind),
      entityId: row.entityId,
      targetType: row.targetType,
      source: row.source,
      status: TempTargetOperationStatus.values.byName(row.status),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
      deliveredAt: row.deliveredAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.deliveredAt!, isUtc: true),
      proposal: payload['proposal'] == null
          ? null
          : TempTargetProposal.fromJson(
              payload['proposal'] as Map<String, dynamic>,
            ),
      attemptedTarget: payload['attemptedTarget'] == null
          ? null
          : OwnedTempTarget.fromJson(
              payload['attemptedTarget'] as Map<String, dynamic>,
            ),
      confirmedTarget: payload['confirmedTarget'] == null
          ? null
          : OwnedTempTarget.fromJson(
              payload['confirmedTarget'] as Map<String, dynamic>,
            ),
      stoppedAt: payload['stoppedAt'] == null
          ? null
          : DateTime.parse(payload['stoppedAt'] as String),
      closedAt: row.closedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.closedAt!, isUtc: true),
    );
  }
}
