import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class DetectFinishedEatingExecutor extends MealMonitorStateExecutor {
  final bool shouldBolus;
  final int? grams;

  DetectFinishedEatingExecutor({required this.shouldBolus, this.grams});

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("DetectFinishedEatingExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("DetectFinishedEatingExecutor");

    return MealMonitorStateIdle();
  }
}
