import 'dart:convert';
import 'dart:math';

import '../../../features/low_treatment/data/repositories/family_treatment_journal.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_remote.dart';
import '../domain/family_treatment_authorization.dart';

typedef FamilyTreatmentResult = ({int? mealId, bool acknowledged});

/// Replays only a previously persisted explicit consumption, never a new action.
Future<void> recoverFamilyTreatmentConsumptions({
  required ConfirmFamilyTreatment executor,
  required bool Function() admitted,
}) async {
  if (!admitted()) return;
  final guard = await executor.chatDb.activeChat();
  if (!admitted() ||
      guard['enabled'] != true ||
      guard['uid'] != executor.currentUid()) {
    return;
  }
  final scope = jsonDecode(guard['scope'] as String) as List;
  if (scope.length != 3 ||
      scope[0] != guard['uid'] ||
      scope[1] is! String ||
      scope[2] is! String) {
    return;
  }
  final installation = await executor.chatDb.fence.nextRegistration();
  if (!admitted() || !await executor._allowed(guard)) return;
  final pending = await executor.journal.pendingConsumptions(
    uid: scope[0] as String,
    familyId: scope[1] as String,
    epoch: scope[2] as String,
    installationId: installation['installationId'] as String,
  );
  for (final operation in pending) {
    if (!admitted() || !await executor._allowed(guard)) return;
    // Rotate before HTTP: inaccessible sources cannot starve a newer intention.
    await executor.journal.markConsumptionAttempt(operation);
    if (!admitted() || operation.authorization == null) continue;
    try {
      await executor.confirm(
        operation.messageId,
        recovery: true,
        actualQuantity: operation.actualQuantity,
        recoveryOperation: operation,
        recoveryGuard: guard,
        recoveryAdmitted: admitted,
      );
    } on CallableFailure catch (failure) {
      if (failure.rejectionCode == 'consumption-consent-revoked' ||
          failure.rejectionCode == 'consumption-unversioned-intent' ||
          failure.rejectionCode == 'not-found' &&
              const {
                'consumption-request-expired',
                'consumption-request-unavailable',
              }.contains(failure.rejectionReason)) {
        await executor.journal.cancelConsumption(operation);
      }
      // Generic not-found also covers temporary sender OFF. Keep it retryable.
    } catch (_) {
      // Network, lease and patient initialization failures retain the intent.
    }
  }
}

/// No chat admission is needed to acknowledge a clinical effect already saved.
Future<void> recoverFamilyTreatmentAcknowledgements({
  required FamilyTreatmentJournal journal,
  required FamilyChatApi api,
  required String? Function() currentUid,
}) async {
  final uid = currentUid();
  if (uid == null) return;
  for (final operation in await journal.pendingAcknowledgements(uid)) {
    if (currentUid() != uid) return;
    try {
      await journal.markAcknowledgementAttempt(operation);
      if (currentUid() != uid) return;
      await api.call('completeFamilyChatTreatment', {
        'claimId': operation.claimId,
        'proof': operation.proof,
      });
      if (currentUid() != uid) return;
      await journal.acknowledge(operation);
    } catch (_) {
      // A failed finalization keeps the committed clinical record untouched.
    }
  }
}

/// A deliberate consumption confirmation, never a receipt or a promise to eat.
class ConfirmFamilyTreatment {
  const ConfirmFamilyTreatment({
    required this.chatDb,
    required this.journal,
    required this.api,
    required this.currentUid,
    required this.clinicalAuthorized,
    required this.save,
    this.onPrepared,
    this.observedAuthorization,
  });
  final FamilyChatDatabase chatDb;
  final FamilyTreatmentJournal journal;
  final FamilyChatApi api;
  final String? Function() currentUid;
  final Future<bool> Function(String uid) clinicalAuthorized;
  final Future<int> Function(Map<String, dynamic> snapshot, int? confirmedAt)
  save;
  final Future<void> Function(String id, Map<String, dynamic> guard)?
  onPrepared;
  final FamilyTreatmentAuthorization? Function()? observedAuthorization;

  Future<bool> _allowed(
    Map<String, dynamic> guard, {
    bool Function()? admitted,
  }) async {
    final uid = guard['uid'] as String;
    bool matches(Map<String, dynamic> value) =>
        value['enabled'] == true &&
        ['uid', 'scope', 'stamp'].every((key) => value[key] == guard[key]);
    if (admitted?.call() == false ||
        currentUid() != uid ||
        !matches(await chatDb.activeChat())) {
      return false;
    }
    if (!await clinicalAuthorized(uid)) return false;
    final latest = await chatDb.activeChat();
    return admitted?.call() != false && currentUid() == uid && matches(latest);
  }

  Future<FamilyTreatmentResult> confirm(
    String messageId, {
    double? actualQuantity,
    bool recovery = false,
    FamilyTreatmentOperation? recoveryOperation,
    Map<String, dynamic>? recoveryGuard,
    bool Function()? recoveryAdmitted,
    FamilyTreatmentAuthorization? acceptedAuthorization,
    Future<void> Function(int mealId)? onSaved,
  }) async {
    // Capture the version attached to the explicit action before any await.
    final observed = acceptedAuthorization ?? observedAuthorization?.call();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(messageId)) {
      throw ArgumentError('Invalid request');
    }
    final guard = await chatDb.activeChat();
    if (recoveryGuard != null &&
        [
          'enabled',
          'uid',
          'scope',
          'stamp',
        ].any((key) => guard[key] != recoveryGuard[key])) {
      throw StateError('Recovery admission changed');
    }
    if (guard['uid'] is! String ||
        !await _allowed(guard, admitted: recoveryAdmitted)) {
      throw StateError('Patient authorization unavailable');
    }
    final uid = guard['uid'] as String;
    final scope = jsonDecode(guard['scope'] as String) as List;
    if (scope.length != 3 ||
        scope[0] != uid ||
        scope[1] is! String ||
        scope[2] is! String) {
      throw StateError('Family scope unavailable');
    }
    final installation = await chatDb.fence.nextRegistration();
    final proof = base64Url
        .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    final existing = await journal.find(uid, scope[1] as String, messageId);
    if (recoveryOperation != null &&
        (existing == null ||
            existing.claimId != recoveryOperation.claimId ||
            existing.uid != recoveryOperation.uid ||
            existing.familyId != recoveryOperation.familyId ||
            existing.installationId != recoveryOperation.installationId ||
            existing.proof != recoveryOperation.proof)) {
      throw StateError('Recovery intention changed');
    }
    if (existing != null &&
        (existing.installationId != installation['installationId'] ||
            actualQuantity != null &&
                existing.actualQuantity != actualQuantity)) {
      throw StateError('Consumption intent is already fixed');
    }
    if (recovery &&
        (existing == null ||
            existing.installationId != installation['installationId'] ||
            actualQuantity != null &&
                existing.actualQuantity != actualQuantity)) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-intent-unavailable',
      );
    }
    if (existing?.mealId == null &&
        existing?.acknowledged != true &&
        !recovery &&
        observed == null) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-authorization-unavailable',
      );
    }
    final operation =
        existing ??
        await journal.prepare(
          uid: uid,
          familyId: scope[1] as String,
          messageId: messageId,
          installationId: installation['installationId'] as String,
          proof: proof,
          actualQuantity: actualQuantity,
          authorization: observed,
          authorized: () => _allowed(guard, admitted: recoveryAdmitted),
        );
    if (operation.mealId != null || operation.acknowledged) {
      return (
        mealId: operation.mealId,
        acknowledged: operation.acknowledged || await finish(operation),
      );
    }
    if (operation.cancelled) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-consent-revoked',
      );
    }
    if (operation.actualQuantity != null) {
      await onPrepared?.call(messageId, guard);
      if (actualQuantity == null) {
        throw const CallableFailure(
          'failed-precondition',
          rejectionCode: 'consumption-quantity-fixed',
        );
      }
    }
    if (operation.authorization == null) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-unversioned-intent',
      );
    }
    if (!recovery && operation.authorization != observed) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-consent-revoked',
      );
    }
    // A cleared/evicted parent cannot lend a new history generation to an old
    // button or an unapplied recovery intent. Recorded effects return above.
    final parent = await chatDb.message(guard['scope'] as String, messageId);
    final historyGeneration = parent?['historyGeneration'] ?? 0;
    if (parent?['kind'] != 'lowTreatment' ||
        historyGeneration is! int ||
        !await chatDb.historyAllows(
          guard['scope'] as String,
          historyGeneration,
        )) {
      throw StateError('Treatment source unavailable');
    }
    // The minimal intent and its proof are durable before any attestation/HTTP.
    final config = await api.call('getFamilyChatConfig', {});
    final member = (config['members'] as List?)
        ?.cast<Map>()
        .where((member) => member['uid'] == uid)
        .firstOrNull;
    if (config['uid'] != uid ||
        config['familyId'] != scope[1] ||
        config['epoch'] != scope[2] ||
        config['account']?['enabled'] != true ||
        config['policy']?['enabled'] != true ||
        member?['role'] != 'child' ||
        !await _allowed(guard, admitted: recoveryAdmitted)) {
      throw StateError('Family request unavailable');
    }
    final authorization = familyTreatmentAuthorizationFromConfig(config);
    if (authorization == null) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-authorization-unavailable',
      );
    }
    if (operation.authorization != authorization) {
      throw const CallableFailure(
        'failed-precondition',
        rejectionCode: 'consumption-consent-revoked',
      );
    }
    final watch = Stopwatch()..start();
    final claim = await api.call(
      'claimFamilyChatTreatment',
      {
        'messageId': messageId,
        'installationId': operation.installationId,
        'proof': operation.proof,
        if (operation.actualQuantity != null)
          'quantity': operation.actualQuantity,
        'authorization': familyTreatmentAuthorizationJson(authorization),
      },
      allowRequest: () async {
        if (!await _allowed(guard, admitted: recoveryAdmitted)) return false;
        final admitted = await chatDb.withChatGuard(
          {...guard, 'historyGeneration': historyGeneration},
          () async => currentUid() == uid && recoveryAdmitted?.call() != false,
        );
        return admitted == true &&
            currentUid() == uid &&
            recoveryAdmitted?.call() != false;
      },
    );
    if (claim['claimId'] != operation.claimId ||
        !await _allowed(guard, admitted: recoveryAdmitted)) {
      throw StateError('Treatment claim unavailable');
    }
    if (claim['completed'] == true) {
      await journal.acknowledgeRemote(operation);
      return (mealId: null, acknowledged: true);
    }
    final serverTime = claim['serverTime'], until = claim['executionUntil'];
    if (serverTime is! int ||
        until is! int ||
        until <= serverTime ||
        until - serverTime > 60000 ||
        claim['treatment'] is! Map) {
      throw StateError('Invalid treatment lease');
    }
    final snapshot = Map<String, dynamic>.from(claim['treatment'] as Map);
    if (operation.actualQuantity != null &&
        snapshot['quantity'] != operation.actualQuantity) {
      throw StateError('Claim changed the confirmed quantity');
    }
    var savedHere = false;
    final mealId = await journal.apply(
      operation,
      authorized: () => _allowed(guard, admitted: recoveryAdmitted),
      save: () async {
        final id = await save(snapshot, operation.confirmedAt);
        savedHere = true;
        return id;
      },
      elapsedMilliseconds: () => watch.elapsedMilliseconds,
      // Starting before HTTP conservatively includes the whole round trip.
      deadlineMilliseconds: until - serverTime,
      appliedAt: serverTime,
    );
    final acknowledged = await finish(operation);
    if (savedHere && !recovery && currentUid() == uid) {
      await onSaved?.call(mealId);
    }
    return (mealId: mealId, acknowledged: acknowledged);
  }

  Future<FamilyTreatmentResult?> lookup(String messageId) async {
    final guard = await chatDb.activeChat();
    if (guard['uid'] is! String || !await _allowed(guard)) return null;
    final scope = jsonDecode(guard['scope'] as String) as List;
    final operation = await journal.find(
      guard['uid'] as String,
      scope[1] as String,
      messageId,
    );
    return operation == null
        ? null
        : (mealId: operation.mealId, acknowledged: operation.acknowledged);
  }

  Future<double?> lookupQuantity(String messageId) async {
    final guard = await chatDb.activeChat();
    if (guard['uid'] is! String || !await _allowed(guard)) return null;
    final scope = jsonDecode(guard['scope'] as String) as List;
    return (await journal.find(
      guard['uid'] as String,
      scope[1] as String,
      messageId,
    ))?.actualQuantity;
  }

  /// Only an existing clinical result can finalize after OFF/unlink/expiry.
  Future<bool> finish(FamilyTreatmentOperation operation) async {
    final current = await journal.get(operation.claimId, operation.uid);
    if (current == null ||
        current.mealId == null ||
        currentUid() != operation.uid) {
      return false;
    }
    if (current.acknowledged) return true;
    try {
      await api.call('completeFamilyChatTreatment', {
        'claimId': current.claimId,
        'proof': current.proof,
      });
      await journal.acknowledge(current);
      return true;
    } catch (_) {
      // The clinical result remains committed; retry only this minimal ACK.
      return false;
    }
  }
}
