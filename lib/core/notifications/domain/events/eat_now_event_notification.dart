import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class EatNowNotificationEvent implements NotificationEvent {
  EatNowNotificationEvent({required this.mealId, required this.minutes});

  final int mealId;
  final int minutes;

  @override
  NotificationEventType get type => NotificationEventType.eatNow;

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => 'Możesz już jeść 🍽️';

  @override
  String get body => 'Minęło $minutes minut od podania insuliny.';

  @override
  Map<String, Object?> toPayload() => {'mealId': mealId, 'minutes': minutes};

  factory EatNowNotificationEvent.fromPayload(Map<String, dynamic> json) {
    return EatNowNotificationEvent(
      mealId: json['mealId'] as int,
      minutes: json['minutes'] as int,
    );
  }
}
