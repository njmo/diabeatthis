import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class FinishedEatingNotificationEvent implements NotificationEvent {
  FinishedEatingNotificationEvent({required this.mealId});

  final int mealId;

  @override
  NotificationEventType get type => NotificationEventType.finishedEating;

  @override
  String get notificationResponseEvent => 'finished_eating_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => 'Zjadłeś już ?';

  @override
  String get body => 'Daj zać czy posilek juz zjeczony czy jeszcze nie';

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId},
  };

  @override
  Map<String, Object?> toJson() => {'mealId': mealId};

  factory FinishedEatingNotificationEvent.fromPayload(Map<String, dynamic> json) {
    return FinishedEatingNotificationEvent(
      mealId: json['mealId'] as int,
    );
  }
}
