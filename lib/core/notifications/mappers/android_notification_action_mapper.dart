import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_action_def.dart';
import '../domain/models/notification_action_type.dart';
import 'android_notification_action_input_mapper.dart';

class AndroidNotificationActionMapper {
  final AndroidNotificationActionInputMapper _inputMapper =
      const AndroidNotificationActionInputMapper();

  const AndroidNotificationActionMapper();

  AndroidNotificationAction _mapPlain(PlainNotificationActionDef action) {
    return AndroidNotificationAction(
      action.type.toDarwinString(),
      action.label,
      showsUserInterface: false,
      cancelNotification: true,
    );
  }

  AndroidNotificationAction _mapText(TextNotificationActionDef action) {
    return AndroidNotificationAction(
      action.type.toDarwinString(),
      action.label,
      showsUserInterface: false,
      cancelNotification: true,
      inputs: [_inputMapper.map(action.inputActionDef)],
    );
  }

  AndroidNotificationAction map(NotificationActionDef action) {
    return action.map(plain: _mapPlain, text: _mapText);
  }
}
