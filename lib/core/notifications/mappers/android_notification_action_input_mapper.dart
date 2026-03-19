import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/notification_action_input_def.dart';

class AndroidNotificationActionInputMapper {
  const AndroidNotificationActionInputMapper();

  AndroidNotificationActionInput map(NotificationActionInputDef action) {
    return AndroidNotificationActionInput(
        label : action.title
    );
  }
}