import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/data/provider/notification_action_handler_provider.dart';
import '../app_container.dart';

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  debugPrint(
    'BG RESPONSE: actionId=${response.actionId} payload=${response.payload}',
  );

  appContainer
      .read(notificationActionHandlerProvider.notifier)
      .handle(response);
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {
  debugPrint(
    'BG BACKGROUND RESPONSE: actionId=${response.actionId} payload=${response.payload}',
  );

  appContainer
      .read(notificationActionHandlerProvider.notifier)
      .handleBackground(response);
}
