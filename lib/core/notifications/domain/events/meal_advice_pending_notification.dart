import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class MealAdvicePendingNotificationEvent implements NotificationEvent {
  const MealAdvicePendingNotificationEvent({required this.mealId});

  final int mealId;

  @override
  NotificationEventType get type => NotificationEventType.mealAdvicePending;

  @override
  String get notificationResponseEvent => '';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => 'Dokończ decyzję o posiłku';

  @override
  String get body => 'Potwierdź propozycję albo anuluj, jeśli nie jesz.';

  @override
  Map<String, Object?> toPayload() => {};

  @override
  Map<String, Object?> toJson() => {'mealId': mealId};

  factory MealAdvicePendingNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return MealAdvicePendingNotificationEvent(mealId: json['mealId'] as int);
  }
}
