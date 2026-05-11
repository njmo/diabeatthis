import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class FinishedEatingNotificationEvent implements NotificationEvent {
  FinishedEatingNotificationEvent({required this.mealId, this.isAddOn = false});

  final int mealId;
  final bool isAddOn;

  @override
  NotificationEventType get type => NotificationEventType.finishedEating;

  @override
  String get notificationResponseEvent => 'finished_eating_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => isAddOn ? 'Dokładka zjedzona?' : 'Zjadłeś już?';

  @override
  String get body => isAddOn
      ? 'Daj znać, czy dokładka jest już zjedzona.'
      : 'Daj znać, czy posiłek jest już zjedzony.';

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId, 'isAddOn': isAddOn},
  };

  @override
  Map<String, Object?> toJson() => {'mealId': mealId, 'isAddOn': isAddOn};

  factory FinishedEatingNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return FinishedEatingNotificationEvent(
      mealId: json['mealId'] as int,
      isAddOn: json['isAddOn'] as bool? ?? false,
    );
  }
}
