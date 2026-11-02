import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/base/notifications_controller.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';

final interruptMealUseCaseProvider = Provider<InterruptMealUseCase>((ref) {
  return InterruptMealUseCase(
    database: ref.watch(databaseProvider),
    notifications: ref.watch(notificationsControllerUiProvider),
  );
});

class InterruptMealUseCase {
  final DatabaseImpl database;
  final NotificationsController notifications;

  const InterruptMealUseCase({
    required this.database,
    required this.notifications,
  });

  Future<bool> call(int mealId, {String? expectedStatus}) async {
    final stopped = await database.mealDao.interruptMeal(
      mealId,
      expectedStatus: expectedStatus,
    );
    if (!stopped) return false;
    // The interruption is committed. A notification failure must not report
    // that the meal is still active or invite a duplicate state change.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await notifications.cancelMealNotifications(
          mealId,
          includeTargetConsent: true,
          includeBolusInstructions: true,
        );
        break;
      } catch (error, stackTrace) {
        Log.e(
          'InterruptMealUseCase',
          'Meal notification cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    return true;
  }
}
