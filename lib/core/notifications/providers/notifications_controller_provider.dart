import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/notifications_controller.dart';
import '../controllers/foreground_task_notification_controller.dart';
import '../controllers/in_app_notifications_controller.dart';
import '../controllers/notifications_controller_impl.dart';

part 'notifications_controller_provider.g.dart';

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerUi(Ref ref) {
  final notificationsController = NotificationsControllerImpl(ref, InAppNotificationsController());

  return notificationsController;
}

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerForeground(Ref ref) {
  final notificationsController = NotificationsControllerImpl(ref, ForegroundTaskNotificationController());

  return notificationsController;
}