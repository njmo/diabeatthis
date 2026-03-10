import '../application/notification_definition_catalog.dart';
import '../domain/models/notification_definition.dart';
import '../domain/models/notification_event_type.dart';
import 'event/eat_now_notification_definition.dart';

class NotificationDefinitionCatalogImpl implements NotificationDefinitionCatalog {
  static const _definitions = [
    mealReadyNotificationDefinition,
  ];

  @override
  NotificationDefinition byType(NotificationEventType type) {
    return _definitions.firstWhere((d) => d.type == type);
  }

  @override
  List<NotificationDefinition> get all => _definitions;
}