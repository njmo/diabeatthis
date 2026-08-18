import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_action_def.dart';
import '../domain/models/notification_action_type.dart';

class DarwinNotificationActionMapper {
  const DarwinNotificationActionMapper();

  DarwinNotificationAction _mapPlain(PlainNotificationActionDef action) {
    return DarwinNotificationAction.plain(
      action.type.toDarwinString(),
      action.label,
      options: action.openApp
          ? <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            }
          : <DarwinNotificationActionOption>{},
    );
  }

  DarwinNotificationAction _mapText(TextNotificationActionDef action) {
    return DarwinNotificationAction.text(
      action.type.toDarwinString(),
      action.label,
      options: action.openApp
          ? <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            }
          : <DarwinNotificationActionOption>{},
      buttonTitle: action.inputActionDef.title,
      placeholder: action.inputActionDef.placeholderText,
    );
  }

  DarwinNotificationAction map(NotificationActionDef action) {
    return action.map(plain: _mapPlain, text: _mapText);
  }
}
