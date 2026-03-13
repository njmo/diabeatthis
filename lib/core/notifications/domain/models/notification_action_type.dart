enum NotificationActionType {
  eating,
  dismiss,
}

extension NotificationActionTypeExtension on NotificationActionType {
  String toDarwinString() {
    switch (this) {
      case NotificationActionType.eating:
        return 'eating';
      case NotificationActionType.dismiss:
        return 'dismiss';
    }
  }
}