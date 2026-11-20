import '../../backend/authenticated_callable_transport.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_remote.dart';
import 'confirm_family_treatment.dart';
import 'family_chat_background.dart';

enum FamilyConsumptionNotice {
  recorded,
  recordedAwaitingAck,
  completedElsewhere,
  pending,
  unavailable,
  anotherDevice,
}

/// Only the dedicated Android action represents actual consumption. A normal
/// RemoteInput answer, even the text "Zjadłem", remains an ordinary message.
Future<bool> handleFamilyChatConsumption({
  required FamilyChatDatabase db,
  required FamilyChatApi api,
  required Map<String, dynamic> payload,
  required String? Function() currentUid,
  required Future<FamilyTreatmentResult> Function(
    String id,
    Map<String, dynamic> guard,
  )
  confirm,
  required Future<FamilyTreatmentResult?> Function(
    String id,
    Map<String, dynamic> guard,
  )
  lookup,
  required Future<void> Function(
    FamilyChatNotice notice,
    FamilyConsumptionNotice state,
    int? mealId,
  )
  show,
  required Future<void> Function(FamilyChatNotice notice) cancel,
}) async {
  bool id(Object? value) =>
      value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
  if (payload['type'] != 'familyChat' ||
      !id(payload['uid']) ||
      !id(payload['messageId']) ||
      payload['scope'] is! String ||
      payload['stamp'] is! String ||
      (payload['scope'] as String).length > 1024 ||
      (payload['stamp'] as String).length > 128) {
    return false;
  }
  final generation = payload['historyGeneration'] ?? 0;
  if (generation is! int) return false;
  final guard = {...await db.activeChat(), 'historyGeneration': generation};
  final uid = payload['uid'] as String,
      scope = payload['scope'] as String,
      messageId = payload['messageId'] as String;
  bool matches(Map<String, dynamic> value) =>
      value['enabled'] == true &&
      ['uid', 'scope', 'stamp'].every((key) => value[key] == payload[key]);
  if (currentUid() != uid ||
      !matches(guard) ||
      !await db.historyAllows(scope, generation)) {
    return false;
  }
  FamilyTreatmentResult? result;
  Object? failure;
  try {
    result = await confirm(messageId, guard);
  } catch (error) {
    failure = error;
    try {
      result = await lookup(messageId, guard);
    } catch (_) {
      /* No clinical success can be inferred. */
    }
  }
  if (currentUid() != uid ||
      !matches(await db.activeChat()) ||
      !await db.historyAllows(scope, generation)) {
    return true;
  }
  final rejection = failure is CallableFailure
      ? failure.rejectionCode ??
            ([
                  'unavailable',
                  'deadline-exceeded',
                  'network',
                ].contains(failure.code)
                ? null
                : failure.code)
      : null;
  final state = result?.mealId != null
      ? result!.acknowledged
            ? FamilyConsumptionNotice.recorded
            : FamilyConsumptionNotice.recordedAwaitingAck
      : result?.acknowledged == true
      ? FamilyConsumptionNotice.completedElsewhere
      : rejection == 'already-exists'
      ? FamilyConsumptionNotice.anotherDevice
      : rejection != null || result == null
      ? FamilyConsumptionNotice.unavailable
      : FamilyConsumptionNotice.pending;
  if (result != null) {
    await db.withChatGuard(
      guard,
      () => db.queueReceipt(scope, messageId, true),
    );
  }
  final notice = familyChatNotice(scope, messageId);
  if (!await db.hasCancellationIntent(notice) &&
      !await db.prepareNotification(guard, notice)) {
    return true;
  }
  final shown = await db.withChatGuard<bool>(guard, () async {
    if (currentUid() != uid) return false;
    final latest = await db.message(scope, messageId);
    if (latest?['_notificationSuppressed'] == true ||
        latest?['receipts']?[uid]?['readAt'] != null ||
        await db.notificationCancelling(scope, notice.tag)) {
      return false;
    }
    await show(notice, state, result?.mealId);
    await db.markNotificationShown(guard, notice);
    return true;
  });
  if (shown != true || currentUid() != uid) {
    try {
      await cancel(notice);
      await db.confirmCancelled(notice);
    } catch (_) {
      /* Keep the identifier for durable cancellation recovery. */
    }
    return true;
  }
  if (result != null && currentUid() == uid) {
    try {
      await api
          .call('acknowledgeFamilyChatMessages', {
            'items': [
              {'messageId': messageId, 'read': true},
            ],
          })
          .timeout(const Duration(seconds: 2));
      await db.withChatGuard(
        guard,
        () => db.completeReceipt(scope, messageId, true),
      );
    } catch (_) {
      /* Keep the durable read ACK for foreground recovery. */
    }
  }
  return true;
}
