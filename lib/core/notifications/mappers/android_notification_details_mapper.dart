import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../application/notification_channel_definition_catalog.dart';
import '../application/notification_definition_catalog.dart';
import '../definitions/notification_channel_catalog_impl.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/models/notification_event.dart';
import 'android_notification_action_mapper.dart';

class AndroidNotificationDetailsMapper {
  final NotificationDefinitionCatalog _catalog = NotificationDefinitionCatalogImpl();
  final NotificationChannelDefinitionCatalog _channelCatalog = NotificationChannelDefinitionCatalogImpl();
  final AndroidNotificationActionMapper _actionMapper = AndroidNotificationActionMapper();

  AndroidNotificationDetails map(NotificationEvent event) {
    final eventDefinition = _catalog.byType(event.type);
    final channelDefinition = _channelCatalog.byType(eventDefinition.channelType);

    return AndroidNotificationDetails(
      channelDefinition.id,
      channelDefinition.name,
      channelDescription: channelDefinition.description,
      importance: channelDefinition.importance,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      groupKey: eventDefinition.categoryId,
      actions: eventDefinition.actions.map(_actionMapper.map).toList(),
    );
  }
}

extension NotificationEventExtensions on NotificationEvent {
  AndroidNotificationDetails toAndroidNotificationDetails() => AndroidNotificationDetailsMapper().map(this);
}