import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../base/notification_definition_catalog.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/models/notification_event.dart';

class DarwinNotificationDetailsMapper {
  final NotificationDefinitionCatalog _catalog =
      NotificationDefinitionCatalogImpl();

  DarwinNotificationDetails map(NotificationEvent event) {
    final definition = _catalog.byType(event.type);

    return DarwinNotificationDetails(
      categoryIdentifier: definition.categoryId,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );
  }
}

extension NotificationEventExtensions on NotificationEvent {
  DarwinNotificationDetails toDarwinNotificationDetails() =>
      DarwinNotificationDetailsMapper().map(this);
}
