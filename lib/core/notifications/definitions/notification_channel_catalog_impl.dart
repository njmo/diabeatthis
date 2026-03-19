import '../base/notification_channel_definition_catalog.dart';
import '../domain/models/notification_channel_type.dart';
import '../domain/models/notifications_channel_definition.dart';
import 'channel/meal_notification_channel_definition.dart';
import 'channel/temp_target_notification_channel_definition.dart';

class NotificationChannelDefinitionCatalogImpl implements NotificationChannelDefinitionCatalog {
  static const _definitions = [
    mealNotificationChannelDefinition,
    targetNotificationChannelDefinition,
  ];

  @override
  NotificationChannelDefinition byType(NotificationChannelType type) {
    return _definitions.firstWhere((d) => d.type == type);
  }

  @override
  List<NotificationChannelDefinition> get all => _definitions;
}