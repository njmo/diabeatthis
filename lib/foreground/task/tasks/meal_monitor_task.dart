import '../../event/internal/meal_status_changed_event.dart';
import '../base/task_context.dart';
import '../base/workflow_task.dart';

class MealMonitorTask extends WorkflowTask {
  @override
  Future<void> run(TaskContext context) async {
    while (true) {
      final mealStartedEvent = await Future.any([
        context.waitForEvent<MealEatingThenBolus>(),
        context.waitForEvent<MealStartedEatingEvent>(),
        context.waitForEvent<MealBolusedEatingEvent>(),
      ]);
      print(
        "Handled meal started eating event ${mealStartedEvent.mealId} - starting monitoring",
      );

      final mealEatenEvent = await Future.any([
        context.waitForEvent<MealFinishedEatingEvent>(),
        context.waitForEvent<MealFinishedEatingBolusedEvent>(),
      ]);
      print(
        "Handled meal finished event ${mealEatenEvent.mealId} stopping meal monitoring, waiting for next",
      );
    }
  }
}
