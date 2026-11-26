import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_event_router_provider.dart';
import '../../core/logger/logger.dart';
import '../../core/notifications/domain/models/notification_event_type.dart';
import '../../core/notifications/domain/models/notification_key.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import '../../foreground/event/internal/meal_decision_finished.dart';
import '../notifications/scoped_notification_cancellation.dart';

final finishMealDecisionProvider = Provider((ref) => FinishMealDecision(ref));

/// Ends a meal decision (accepted or rejected) after it was committed: the
/// meal advisor offer for that meal is obsolete, so its notification is
/// cleared and the foreground monitor waiting for an answer re-evaluates.
class FinishMealDecision {
  const FinishMealDecision(this.ref);
  final Ref ref;

  Future<void> call(int mealId) async {
    try {
      // The advisor offer for a planned meal uses its own key, unlike bolus
      // reminders, so a reminder shown right after acceptance stays.
      await ref
          .read(notificationsControllerUiProvider)
          .cancelNotification(
            NotificationKey(
              type: NotificationEventType.plannedMealAdvice,
              entityId: mealId,
            ),
          );
    } catch (error) {
      Log.w('FinishMealDecision', 'Could not clear the advisor offer: $error');
    }
    try {
      ref.read(appEventRouterProvider).send(MealDecisionFinished(mealId));
    } catch (error) {
      Log.w('FinishMealDecision', 'Could not notify the monitor: $error');
    }
  }
}
