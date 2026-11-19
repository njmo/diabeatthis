import '../events/family_chat_notification.dart';
import 'notification_event.dart';
import 'notification_event_type.dart';

const notificationRetryDelay = Duration(minutes: 5);

enum NotificationRetryPolicy { none, untilRead, untilAnswered }

NotificationRetryPolicy notificationRetryPolicy(NotificationEvent event) {
  if (event.type == NotificationEventType.finishedEating) {
    return NotificationRetryPolicy.untilAnswered;
  }
  if (event is FamilyChatNotificationEvent &&
      event.message != null &&
      !event.silent &&
      !event.transient) {
    if (event.payload['authorization'] != null || event.allowConsumption) {
      return NotificationRetryPolicy.none;
    }
    return event.replyChoices.isNotEmpty
        ? NotificationRetryPolicy.untilAnswered
        : NotificationRetryPolicy.untilRead;
  }
  return NotificationRetryPolicy.none;
}
