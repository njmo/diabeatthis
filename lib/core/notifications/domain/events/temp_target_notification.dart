import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class TempTargetNotificationEvent implements NotificationEvent {
  TempTargetNotificationEvent({required this.tempTargetString});

  final String tempTargetString;

  @override
  NotificationEventType get type => NotificationEventType.tempTarget;

  @override
  String get notificationResponseEvent => 'temp_target_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: 0);

  @override
  String get title => 'Propozycja zmiany targetu glikemii';

  @override
  String get body => 'Ustaw target glikemii na $tempTargetString';

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'tempTargetString': tempTargetString},
  };

  @override
  Map<String, Object?> toJson() => {'tempTargetString': tempTargetString};

  factory TempTargetNotificationEvent.fromPayload(Map<String, dynamic> json) {
    return TempTargetNotificationEvent(
      tempTargetString: json['tempTargetString'] as String,
    );
  }
}
