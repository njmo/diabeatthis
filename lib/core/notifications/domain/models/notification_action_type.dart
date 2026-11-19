enum NotificationActionType {
  eating,
  snooze,
  dismiss,
  skip,
  agree,
  familyChatReply,
  familyChatConsume,
}

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
      case NotificationActionType.familyChatReply:
        return 'family_chat_reply';
      case NotificationActionType.familyChatConsume:
        return 'family_chat_consume';
    }
  }
}
