import '../../core/notifications/base/notifications_controller.dart';
import '../../core/notifications/domain/events/temp_target_notification.dart';
import '../../core/notifications/domain/models/notification_event_type.dart';
import '../../core/notifications/domain/models/notification_key.dart';
import 'scoped_notification_cancellation.dart';

extension MealNotificationCancellation on NotificationsController {
  /// Intermediate meal steps preserve consent; terminal cleanup opts in after
  /// the meal lifecycle has made that target proposal invalid.
  Future<void> cancelMealNotifications(
    int mealId, {
    bool includeTargetConsent = false,
    bool includeBolusInstructions = false,
    bool includeBolusReminder = true,
  }) async {
    if (includeTargetConsent) {
      await cancelNotification(
        TempTargetNotificationEvent.meal(entityId: mealId).key,
      );
    }
    for (final type in [
      NotificationEventType.eatNow,
      NotificationEventType.finishedEating,
      if (includeBolusReminder) NotificationEventType.mealSuggestion,
      NotificationEventType.mealAdvicePending,
      NotificationEventType.mealSummaryReminder,
      if (includeBolusInstructions) NotificationEventType.aapsBolusSuggestion,
    ]) {
      await cancelNotification(NotificationKey(type: type, entityId: mealId));
    }
  }
}
