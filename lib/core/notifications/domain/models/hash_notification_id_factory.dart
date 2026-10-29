import 'notification_key.dart';

class HashNotificationIdFactory implements NotificationIdFactory {
  const HashNotificationIdFactory();

  @override
  int create(NotificationKey key) {
    // OS notifications outlive isolates and process restarts. Neither
    // Object.hash nor an enum's hashCode provides a persistent identifier.
    var hash = 0;
    for (final unit in '${key.type.name}:${key.entityId}'.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}

abstract class NotificationIdFactory {
  int create(NotificationKey key);
}
