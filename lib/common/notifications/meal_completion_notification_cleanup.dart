import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import 'meal_notification_cancellation.dart';

/// Shared post-commit cleanup; a failed platform call never invalidates a save.
final mealCompletionNotificationCleanupProvider =
    Provider<MealCompletionNotificationCleanup>(
      (ref) => MealCompletionNotificationCleanup(ref),
    );

class MealCompletionNotificationCleanup {
  const MealCompletionNotificationCleanup(this.ref);
  final Ref ref;

  Future<void> call(int mealId, {required bool requiresBolus}) async {
    // Persistence is already committed. Notification cleanup must never make
    // the screen offer to repeat consumption or append the extra items again.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await ref
            .read(notificationsControllerUiProvider)
            .cancelMealNotifications(
              mealId,
              includeTargetConsent: !requiresBolus,
              includeBolusInstructions: true,
              // The committed waiting state may already have posted its new
              // reminder in the foreground isolate.
              includeBolusReminder: !requiresBolus,
            );
        break;
      } catch (error, stackTrace) {
        Log.e(
          'MealCompletionNotifications',
          'Meal notification cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
