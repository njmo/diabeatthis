enum NotificationActionType { eating, snooze, dismiss, skip, agree }

extension NotificationActionTypeExtension on NotificationActionType {
  String toDarwinString() {
    switch (this) {
      case NotificationActionType.skip:
        return 'skip';
      case NotificationActionType.eating:
        return 'eating';
      case NotificationActionType.dismiss:
        return 'dismiss';
      case NotificationActionType.snooze:
        return 'snooze';
      case NotificationActionType.agree:
        return 'agree';
    }
  }
}
