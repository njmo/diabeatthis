enum NotificationActionType {
  mealYes,
  mealNotYet,
}

extension NotificationActionTypeExtension on NotificationActionType {
  String toDarwinString() {
    switch (this) {
      case NotificationActionType.mealYes:
        return 'meal_yes';
      case NotificationActionType.mealNotYet:
        return 'meal_not_yet';
    }
  }
}