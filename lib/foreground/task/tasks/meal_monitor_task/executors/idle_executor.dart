import '../../../../event/internal/meal_event.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_monitor_state_executor.dart';

class MealMonitorStateIdle extends MealMonitorStateExecutor {
  MealMonitorStateIdle();

  @override
  List<Type> get interuptableEvents => [
    MealStartedEatingEvent,
    MealBolusedEatingEvent,
    MealBolusedWaitingEvent,
    MealEatingThenBolus,
    NextMealEvent,
  ];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("MealMonitorStateIdle cleanup");
    return Future.value();
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    print("MealMonitorStateIdle");
    await runtimeContext.waitForDuration(Duration(minutes: 30));
    return this;
  }
}
