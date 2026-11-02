import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../base/notification_channel_definition_catalog.dart';
import '../base/notification_definition_catalog.dart';
import '../definitions/notification_channel_catalog_impl.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/models/notification_action_type.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_event_type.dart';
import 'android_notification_action_mapper.dart';

class AndroidNotificationDetailsMapper {
  final NotificationDefinitionCatalog _catalog =
      NotificationDefinitionCatalogImpl();
  final NotificationChannelDefinitionCatalog _channelCatalog =
      NotificationChannelDefinitionCatalogImpl();
  final AndroidNotificationActionMapper _actionMapper =
      AndroidNotificationActionMapper();

  AndroidNotificationDetails map(NotificationEvent event) {
    final eventDefinition = _catalog.byType(event.type);
    final channelDefinition = _channelCatalog.byType(
      eventDefinition.channelType,
    );

    return AndroidNotificationDetails(
      channelDefinition.id,
      channelDefinition.name,
      channelDescription: channelDefinition.description,
      importance: channelDefinition.importance,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      groupKey: eventDefinition.categoryId,
      styleInformation: BigTextStyleInformation(event.body),
      actions: eventDefinition.actions
          .map(
            (action) => _actionMapper.map(
              action,
              showUserInterface:
                  event.type == NotificationEventType.finishedEating &&
                  action.type == NotificationActionType.agree,
            ),
          )
          .toList(),
    );
  }
}

extension NotificationEventExtensions on NotificationEvent {
  AndroidNotificationDetails toAndroidNotificationDetails() =>
      AndroidNotificationDetailsMapper().map(this);
}
