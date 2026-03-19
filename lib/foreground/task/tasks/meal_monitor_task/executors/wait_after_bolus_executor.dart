import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class WaitAfterBolusExecutor extends MealMonitorStateExecutor {
  final int? recommendedMinutes;

  WaitAfterBolusExecutor({this.recommendedMinutes});

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) {
    print("MealMonitorStateWaitAfterBolus cleanup");
    return Future.value();
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("MealMonitorStateWaitAfterBolus");
    return MealMonitorStateIdle();
  }
}
