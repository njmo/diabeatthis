import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_definition.dart';
import 'darwin_notification_action_mapper.dart';

class DarwinNotificationCategoryMapper {
  final _notificationActionMapper = DarwinNotificationActionMapper();

  List<DarwinNotificationCategory> mapDefinitions(
    List<NotificationDefinition> definitions,
  ) {
    return definitions.map((definition) {
      return DarwinNotificationCategory(
        definition.categoryId,
        actions: definition.actions.map(_notificationActionMapper.map).toList(),
      );
    }).toList();
  }
}
