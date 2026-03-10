import 'notification_key.dart';

class HashNotificationIdFactory implements NotificationIdFactory {
  const HashNotificationIdFactory();

  @override
  int create(NotificationKey key) {
    return Object.hash(key.type, key.entityId) & 0x7fffffff;
  }
}

abstract class NotificationIdFactory {
  int create(NotificationKey key);
}