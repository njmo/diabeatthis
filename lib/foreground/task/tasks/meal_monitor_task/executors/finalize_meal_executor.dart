import '../../../../../core/logger/logger.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class FinalizeMealExecutor extends MealMonitorStateExecutor with Logging {
  FinalizeMealExecutor();

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

    return MealMonitorStateIdle();
  }
}
