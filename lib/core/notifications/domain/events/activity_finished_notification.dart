import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class ActivityFinishedNotificationEvent implements NotificationEvent {
  ActivityFinishedNotificationEvent({
    required this.activityLogId,
    required this.activityName,
  });

  final int activityLogId;
  final String activityName;

  @override
  NotificationEventType get type => NotificationEventType.activityFinished;

  @override
  String get notificationResponseEvent => 'activity_finished_response';

  @override
  NotificationKey get key =>
      NotificationKey(type: type, entityId: activityLogId);

  @override
  String get title => 'Trening zakończony?';

  @override
  String get body => 'Daj znać, czy aktywność "$activityName" jest zakończona.';

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'activityLogId': activityLogId},
  };

  @override
  Map<String, Object?> toJson() => {
    'activityLogId': activityLogId,
    'activityName': activityName,
  };

  factory ActivityFinishedNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return ActivityFinishedNotificationEvent(
      activityLogId: json['activityLogId'] as int,
      activityName: json['activityName'] as String,
    );
  }
}
