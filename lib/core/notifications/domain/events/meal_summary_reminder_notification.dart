import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class MealSummaryReminderNotificationEvent implements NotificationEvent {
  MealSummaryReminderNotificationEvent({required this.mealId});

  final int mealId;

  @override
  NotificationEventType get type => NotificationEventType.mealSummaryReminder;

  @override
  String get notificationResponseEvent => 'meal_summary_reminder_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => 'Zrób podsumowanie posiłku';

  @override
  String get body =>
      'Sprawdź, ile naprawdę zostało zjedzone i uzupełnij dokładkę, jeśli była.';

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId},
  };

  @override
  Map<String, Object?> toJson() => {'mealId': mealId};

  factory MealSummaryReminderNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return MealSummaryReminderNotificationEvent(mealId: json['mealId'] as int);
  }
}
