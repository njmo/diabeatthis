import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_action_type.dart';
import '../domain/models/notification_definition.dart';

class DarwinNotificationCategoryMapper {
  List<DarwinNotificationCategory> mapDefinitions(
    List<NotificationDefinition> definitions,
  ) {
    return definitions.map((definition) {
      return DarwinNotificationCategory(
        definition.categoryId,
        actions: definition.actions.map((action) {
          return DarwinNotificationAction.plain(
            action.type.toDarwinString(),
            action.label,
            options: action.openApp
                ? <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  }
                : <DarwinNotificationActionOption>{},
          );
        }).toList(),
      );
    }).toList();
  }
}
