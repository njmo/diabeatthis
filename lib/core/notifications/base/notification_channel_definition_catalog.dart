import '../domain/models/notification_channel_type.dart';
import '../domain/models/notifications_channel_definition.dart';

abstract interface class NotificationChannelDefinitionCatalog {
  NotificationChannelDefinition byType(NotificationChannelType type);
  List<NotificationChannelDefinition> get all;
}