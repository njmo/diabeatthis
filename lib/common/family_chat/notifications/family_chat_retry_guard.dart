import '../../../core/notifications/domain/events/family_chat_notification.dart';
import '../../../core/notifications/domain/models/notification_retry_policy.dart';
import '../../../core/notifications/inbox/notification_inbox_entry.dart';
import '../data/family_chat_database.dart';

/// Rechecks the chat journal and access fence before reusing cached content.
Future<void> withAuthorizedFamilyChatRetry({
  required FamilyChatDatabase db,
  required String? Function() currentUid,
  required NotificationInboxEntry entry,
  required FamilyChatNotificationEvent event,
  required Future<void> Function() deliver,
}) async {
  final uid = currentUid();
  final scope = event.payload['scope'];
  final messageId = event.payload['messageId'];
  if (uid == null ||
      event.payload['uid'] != uid ||
      scope is! String ||
      messageId is! String) {
    return;
  }
  final guard = await db.activeChat();
  if (guard['stamp'] != event.payload['stamp']) return;
  await db.withChatGuard(guard, () async {
    if (currentUid() != uid ||
        (await db.authorizedInbox(uid, [entry])).isEmpty ||
        !await db.notificationShown(scope, event.id, tag: event.tag) ||
        await db.notificationCancelling(scope, event.tag)) {
      return;
    }
    final message = await db.message(scope, messageId);
    final treatment = isActionableFamilyTreatment(event);
    if (message == null ||
        message['_notificationSuppressed'] == true ||
        (treatment &&
            (message['kind'] != 'lowTreatment' ||
                message['treatmentResult'] != null ||
                await db.hasAuthoredReply(scope, uid, messageId) ||
                await db.metadata('notificationReply:$scope:$messageId') !=
                    null)) ||
        (!treatment &&
            event.replyChoices.isEmpty &&
            (message['receipts']?[uid]?['readAt'] != null ||
                await db.locallyRead(scope, messageId))) ||
        (message['kind'] == 'question' &&
            await db.hasAuthoredReply(scope, uid, messageId))) {
      return;
    }
    if (currentUid() == uid) await deliver();
  });
}
