import '../../../../common/family_chat/domain/family_treatment_authorization.dart';
import '../events/family_chat_notification.dart';
import 'notification_event.dart';
import 'notification_event_type.dart';

const notificationRetryDelay = Duration(minutes: 5);

bool isActionableFamilyTreatment(NotificationEvent event) =>
    event is FamilyChatNotificationEvent &&
    event.lowTreatment &&
    event.allowConsumption &&
    event.message != null &&
    !event.silent &&
    !event.transient &&
    parseFamilyTreatmentAuthorization(event.payload['authorization']) != null;

Duration notificationRetryDelayFor(NotificationEvent event) =>
    isActionableFamilyTreatment(event)
    ? const Duration(minutes: 1)
    : notificationRetryDelay;

enum NotificationRetryPolicy { none, untilRead, untilAnswered }

NotificationRetryPolicy notificationRetryPolicy(NotificationEvent event) {
  if (event.type == NotificationEventType.finishedEating) {
    return NotificationRetryPolicy.untilAnswered;
  }
  if (event is FamilyChatNotificationEvent &&
      event.message != null &&
      !event.silent &&
      !event.transient) {
    if (isActionableFamilyTreatment(event)) {
      return NotificationRetryPolicy.untilAnswered;
    }
    if (event.payload['authorization'] != null ||
        event.lowTreatment ||
        event.allowConsumption) {
      return NotificationRetryPolicy.none;
    }
    return event.replyChoices.isNotEmpty
        ? NotificationRetryPolicy.untilAnswered
        : NotificationRetryPolicy.untilRead;
  }
  return NotificationRetryPolicy.none;
}
