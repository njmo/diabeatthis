import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import 'eat_now_event_notification.dart';

class NotificationEventFactory {
  const NotificationEventFactory();

  NotificationEvent fromPayload(
      NotificationEventType type,
      Map<String, dynamic> data,
      ) {
    switch (type) {
      case NotificationEventType.eatNow:
        return EatNowNotificationEvent.fromPayload(data);
    }
  }
}