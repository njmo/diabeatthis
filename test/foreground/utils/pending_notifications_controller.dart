import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';

import 'fake_notifications_controller.dart';

class PendingNotificationsController extends FakeNotificationsController {
  final Set<int> activeIds = {};

  bool contains(NotificationEvent event) =>
      activeIds.contains(const HashNotificationIdFactory().create(event.key));

  @override
  Future<void> show(NotificationEvent event) async {
    await super.show(event);
    activeIds.add(const HashNotificationIdFactory().create(event.key));
  }

  @override
  Future<void> cancel(int id) async {
    await super.cancel(id);
    activeIds.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    await super.cancelAll();
    activeIds.clear();
  }
}
