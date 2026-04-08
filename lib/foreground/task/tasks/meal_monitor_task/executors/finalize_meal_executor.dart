import '../../../../../core/logger/logger.dart';
import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_monitor_state_executor.dart';
import 'new_meal_check_executor.dart';

class FinalizeMealExecutor extends MealMonitorStateExecutor with Logging {
  FinalizeMealExecutor();

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
    mealMonitorContext.activeMeal = null;

    final notificationProvider = runtimeContext.container.read(
      notificationsControllerForegroundProvider,
    );
    notificationProvider.cancelAll();

    return NewMealCheckExecutor();
  }
}
