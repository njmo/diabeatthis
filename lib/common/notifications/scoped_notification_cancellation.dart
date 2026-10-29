import '../../core/notifications/base/notifications_controller.dart';
import '../../core/notifications/domain/models/hash_notification_id_factory.dart';
import '../../core/notifications/domain/models/notification_key.dart';

extension ScopedNotificationCancellation on NotificationsController {
  Future<void> cancelNotification(NotificationKey key) =>
      cancel(const HashNotificationIdFactory().create(key));
}
