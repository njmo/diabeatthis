import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class FinalizeMealExecutor extends MealMonitorStateExecutor {
  FinalizeMealExecutor();

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("FinalizeMealExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("FinalizeMealExecutor");
    mealMonitorContext.activeMeal = null;

    return MealMonitorStateIdle();
  }
}
