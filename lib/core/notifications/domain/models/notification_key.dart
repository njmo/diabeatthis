import 'notification_event_type.dart';

class NotificationKey {
  final NotificationEventType type;
  final int entityId;

  const NotificationKey({
    required this.type,
    required this.entityId,
  });
}