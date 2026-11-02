import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

/// Ends tracking without changing recorded food, insulin, or external targets.
class StopMealMonitoringExecutor extends MealMonitorStateExecutor {
  const StopMealMonitoringExecutor({
    required this.mealId,
    this.interrupted = false,
  });

  final int mealId;
  final bool interrupted;

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {}

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    await runtimeContext.container
        .read(notificationsControllerForegroundProvider)
        .cancelMealNotifications(
          mealId,
          includeTargetConsent: true,
          includeBolusInstructions: interrupted,
        );
    mealMonitorContext.activeMeal = null;
    mealMonitorContext.publishStatus(runtimeContext, MealMonitoringPhase.idle);
    runtimeContext.container.invalidate(getNearestMealProvider);
    return NewMealCheckExecutor();
  }
}
