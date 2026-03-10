import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_action_def.dart';
import '../domain/models/notification_action_type.dart';

class AndroidNotificationActionMapper {
  const AndroidNotificationActionMapper();

  AndroidNotificationAction map(NotificationActionDef action) {
    return AndroidNotificationAction(
      action.type.toDarwinString(),
      action.label,
      showsUserInterface: false,
      cancelNotification: true,
    );
  }
}