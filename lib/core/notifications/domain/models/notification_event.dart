import 'notification_event_type.dart';
import 'notification_key.dart';

abstract interface class NotificationEvent {
  NotificationKey get key;
  NotificationEventType get type;
  String get notificationResponseEvent;
  String get title;
  String get body;
  Map<String, Object?> toPayload();
  Map<String, Object?> toJson();
}
