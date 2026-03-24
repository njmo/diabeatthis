import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import 'eat_now_event_notification.dart';
import 'finished_eating_event_notification.dart';
import 'meal_suggestion_notification.dart';
import 'temp_target_notification.dart';

class NotificationEventFactory {
  const NotificationEventFactory();

  NotificationEvent fromPayload(
    NotificationEventType type,
    Map<String, dynamic> data,
  ) {
    switch (type) {
      case NotificationEventType.eatNow:
        return EatNowNotificationEvent.fromPayload(data);
      case NotificationEventType.tempTarget:
        return TempTargetNotificationEvent.fromPayload(data);
      case NotificationEventType.mealSuggestion:
        return MealSuggestionNotificationEvent.fromPayload(data);
      case NotificationEventType.finishedEating:
        return FinishedEatingNotificationEvent.fromPayload(data);
    }
  }
}
