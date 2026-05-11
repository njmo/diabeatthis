import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/domain/events/meal_summary_reminder_notification.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

class FinalizeMealExecutor extends MealMonitorStateExecutor with Logging {
  FinalizeMealExecutor();

  static const summaryReminderDelay = Duration(minutes: 2);

  @override
  List<Type> get interruptableEvents => [];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("FinalizeMealExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("FinalizeMealExecutor");
    final mealId = mealMonitorContext.activeMeal?.id;
    mealMonitorContext.activeMeal = null;

    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    await notificationProvider.cancelAll();

    if (mealId != null) {
      await notificationProvider.schedule(
        MealSummaryReminderNotificationEvent(mealId: mealId),
        summaryReminderDelay,
      );
    }

    return NewMealCheckExecutor();
  }
}
