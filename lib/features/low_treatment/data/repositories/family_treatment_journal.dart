import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;

import '../../../../common/family_chat/domain/family_treatment_authorization.dart';
import '../../../../core/drift/database_impl.dart';

typedef FamilyTreatmentOperation = ({
  String claimId,
  String uid,
  String familyId,
  String messageId,
  String installationId,
  String proof,
  int? mealId,
  bool acknowledged,
  int? confirmedAt,
  double? actualQuantity,
  FamilyTreatmentAuthorization? authorization,
  bool cancelled,
});

/// Clinical idempotency survives chat expiry and deletion of a recorded meal.
/// It contains no message text or food snapshot.
class FamilyTreatmentJournal {
  const FamilyTreatmentJournal(this.db);
  final DatabaseImpl db;

  Future<FamilyTreatmentOperation> prepare({
    required String uid,
    required String familyId,
    required String messageId,
    required String installationId,
    required String proof,
    int? confirmedAt,
    double? actualQuantity,
    FamilyTreatmentAuthorization? authorization,
    Future<bool> Function()? authorized,
  }) => db.transaction(() async {
    if (authorization != null &&
        parseFamilyTreatmentAuthorization(
              familyTreatmentAuthorizationJson(authorization),
            ) !=
            authorization) {
      throw ArgumentError('Invalid consumption authorization');
    }
    if (actualQuantity != null &&
        (!actualQuantity.isFinite ||
            actualQuantity <= 0 ||
            actualQuantity > 10000)) {
      throw ArgumentError('Invalid consumed quantity');
    }
    final claimId = sha256
        .convert(utf8.encode('$familyId:$messageId:$uid'))
        .toString();
    // Fence validation belongs under the writer lock: an old prepare must not
    // insert after OFF's cancellation transaction has already passed it.
    await db.customStatement(
      'UPDATE family_treatment_journal SET acknowledged=acknowledged WHERE claim_id=? AND owner_uid=?',
      [claimId, uid],
    );
    if (authorized != null && !await authorized()) {
      throw StateError('Consumption admission changed');
    }
    await db.customStatement(
      '''INSERT OR IGNORE INTO family_treatment_journal
         (claim_id,owner_uid,family_id,message_id,installation_id,proof,confirmed_at,actual_quantity,authorization_epoch,account_off_generation,family_off_generation)
         VALUES(?,?,?,?,?,?,?,?,?,?,?)''',
      [
        claimId,
        uid,
        familyId,
        messageId,
        installationId,
        proof,
        confirmedAt ?? clock.now().millisecondsSinceEpoch,
        actualQuantity,
        authorization?.epoch,
        authorization?.accountOffGeneration,
        authorization?.familyOffGeneration,
      ],
    );
    await db.customStatement(
      'UPDATE family_treatment_journal SET confirmed_at=COALESCE(confirmed_at,?) WHERE claim_id=? AND owner_uid=?',
      [confirmedAt ?? clock.now().millisecondsSinceEpoch, claimId, uid],
    );
    final existing = await get(claimId, uid);
    if (existing == null || existing.installationId != installationId) {
      throw StateError('Treatment belongs to another installation');
    }
    if (actualQuantity != null && existing.actualQuantity != actualQuantity) {
      throw StateError('Consumption quantity is already fixed');
    }
    return existing;
  });

  Future<FamilyTreatmentOperation?> get(String claimId, String uid) async {
    final row = await db
        .customSelect(
          'SELECT * FROM family_treatment_journal WHERE claim_id=? AND owner_uid=?',
          variables: [Variable(claimId), Variable(uid)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (
      claimId: row.read<String>('claim_id'),
      uid: row.read<String>('owner_uid'),
      familyId: row.read<String>('family_id'),
      messageId: row.read<String>('message_id'),
      installationId: row.read<String>('installation_id'),
      proof: row.read<String>('proof'),
      mealId: row.readNullable<int>('meal_id'),
      acknowledged: row.read<int>('acknowledged') == 1,
      confirmedAt: row.readNullable<int>('confirmed_at'),
      actualQuantity: row.readNullable<double>('actual_quantity'),
      authorization: parseFamilyTreatmentAuthorization({
        'epoch': row.readNullable<String>('authorization_epoch'),
        'accountOffGeneration': row.readNullable<int>('account_off_generation'),
        'familyOffGeneration': row.readNullable<int>('family_off_generation'),
      }),
      cancelled: row.read<int>('cancelled') != 0,
    );
  }

  Future<FamilyTreatmentOperation?> find(
    String uid,
    String familyId,
    String messageId,
  ) => get(
    sha256.convert(utf8.encode('$familyId:$messageId:$uid')).toString(),
    uid,
  );

  /// Local OFF cannot be undone by a later ON while the remote OFF is offline.
  /// Already committed medical effects and their minimal ACKs are preserved.
  Future<void> cancelUnapplied(String uid) => db.customStatement(
    'UPDATE family_treatment_journal SET cancelled=1 WHERE owner_uid=? AND meal_id IS NULL AND acknowledged=0',
    [uid],
  );

  Future<List<FamilyTreatmentOperation>> pendingConsumptions({
    required String uid,
    required String familyId,
    required String installationId,
    required String epoch,
    int limit = 5,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT claim_id FROM family_treatment_journal WHERE owner_uid=? AND family_id=? AND installation_id=? '
          'AND meal_id IS NULL AND acknowledged=0 AND cancelled=0 AND confirmed_at IS NOT NULL '
          'AND authorization_epoch=? AND account_off_generation IS NOT NULL '
          'AND family_off_generation IS NOT NULL ORDER BY ack_attempt_order,confirmed_at,claim_id LIMIT ?',
          variables: [
            Variable(uid),
            Variable(familyId),
            Variable(installationId),
            Variable(epoch),
            Variable(limit.clamp(1, 20)),
          ],
        )
        .get();
    final result = <FamilyTreatmentOperation>[];
    for (final row in rows) {
      final operation = await get(row.read<String>('claim_id'), uid);
      if (operation != null) result.add(operation);
    }
    return result;
  }

  Future<void> markConsumptionAttempt(
    FamilyTreatmentOperation operation,
  ) => db.customStatement(
    'UPDATE family_treatment_journal SET ack_attempt_order=(SELECT COALESCE(MAX(ack_attempt_order),0)+1 FROM family_treatment_journal) '
    'WHERE claim_id=? AND owner_uid=? AND family_id=? AND installation_id=? AND meal_id IS NULL AND acknowledged=0 AND cancelled=0',
    [
      operation.claimId,
      operation.uid,
      operation.familyId,
      operation.installationId,
    ],
  );

  Future<void> cancelConsumption(
    FamilyTreatmentOperation operation,
  ) => db.customStatement(
    'UPDATE family_treatment_journal SET cancelled=1 WHERE claim_id=? AND owner_uid=? AND family_id=? AND installation_id=? '
    'AND meal_id IS NULL AND acknowledged=0',
    [
      operation.claimId,
      operation.uid,
      operation.familyId,
      operation.installationId,
    ],
  );

  /// Only committed clinical effects can be finalized without chat consent.
  /// Prepared but unapplied intentions must never enter this recovery lane.
  Future<List<FamilyTreatmentOperation>> pendingAcknowledgements(
    String uid, {
    int limit = 20,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT claim_id FROM family_treatment_journal WHERE owner_uid=? AND meal_id IS NOT NULL AND acknowledged=0 ORDER BY ack_attempt_order,applied_at,claim_id LIMIT ?',
          variables: [Variable(uid), Variable(limit.clamp(1, 50))],
        )
        .get();
    final result = <FamilyTreatmentOperation>[];
    for (final row in rows) {
      final operation = await get(row.read<String>('claim_id'), uid);
      if (operation != null) result.add(operation);
    }
    return result;
  }

  /// Rotate before HTTP so permanent failures and process death cannot starve
  /// later records. The clinical result and proof are never removed.
  Future<void> markAcknowledgementAttempt(
    FamilyTreatmentOperation operation,
  ) => db.customStatement(
    'UPDATE family_treatment_journal SET ack_attempt_order=(SELECT COALESCE(MAX(ack_attempt_order),0)+1 FROM family_treatment_journal) WHERE claim_id=? AND owner_uid=? AND meal_id IS NOT NULL AND acknowledged=0',
    [operation.claimId, operation.uid],
  );

  Future<int> apply(
    FamilyTreatmentOperation operation, {
    required Future<bool> Function() authorized,
    required Future<int> Function() save,
    required int Function() elapsedMilliseconds,
    required int deadlineMilliseconds,
    required int appliedAt,
  }) => db.transaction(() async {
    // Take the writer before checking the journal, including across isolates.
    await db.customStatement(
      'UPDATE family_treatment_journal SET acknowledged=acknowledged WHERE claim_id=? AND owner_uid=?',
      [operation.claimId, operation.uid],
    );
    final current = await get(operation.claimId, operation.uid);
    if (current == null ||
        current.proof != operation.proof ||
        current.installationId != operation.installationId) {
      throw StateError('Unknown treatment operation');
    }
    if (current.mealId != null) return current.mealId!;
    if (current.cancelled) throw StateError('Consumption intent was cancelled');
    Future<void> check() async {
      // Admission itself may consume the lease; reserve time for SQLite commit.
      final safeDeadline = deadlineMilliseconds - 1000;
      if (elapsedMilliseconds() >= safeDeadline ||
          !await authorized() ||
          elapsedMilliseconds() >= safeDeadline) {
        throw StateError('Treatment authorization expired');
      }
    }

    await check();
    final mealId = await save();
    await check();
    await db.customStatement(
      'UPDATE family_treatment_journal SET meal_id=?,applied_at=? WHERE claim_id=? AND owner_uid=?',
      [mealId, appliedAt, operation.claimId, operation.uid],
    );
    return mealId;
  });

  Future<void> acknowledge(FamilyTreatmentOperation operation) async {
    await db.customStatement(
      'UPDATE family_treatment_journal SET acknowledged=1 WHERE claim_id=? AND owner_uid=? AND proof=? AND meal_id IS NOT NULL',
      [operation.claimId, operation.uid, operation.proof],
    );
  }

  Future<void> acknowledgeRemote(FamilyTreatmentOperation operation) async {
    await db.customStatement(
      'UPDATE family_treatment_journal SET acknowledged=1 WHERE claim_id=? AND owner_uid=? AND proof=? AND meal_id IS NULL',
      [operation.claimId, operation.uid, operation.proof],
    );
  }
}
