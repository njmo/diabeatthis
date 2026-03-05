import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/data/provider/notification_action_handler_provider.dart';
import '../app_container.dart';

void onDidReceiveNotificationResponse(NotificationResponse response) {
  appContainer
      .read(notificationActionHandlerProvider.notifier)
      .handle(response);
}