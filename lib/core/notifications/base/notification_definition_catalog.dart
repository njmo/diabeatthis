import '../domain/models/notification_definition.dart';
import '../domain/models/notification_event_type.dart';

abstract interface class NotificationDefinitionCatalog {
  NotificationDefinition byType(NotificationEventType type);
  List<NotificationDefinition> get all;
}