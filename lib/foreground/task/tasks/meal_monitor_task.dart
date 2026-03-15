import '../../event/internal/meal_status_changed_event.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

class MealMonitorTask extends WorkflowTask {
  @override
  Future<void> run(RuntimeContext context) async {
    while (true) {
      final mealStartedEvent = await context.any([
        context.eventWait<MealEatingThenBolus>(),
        context.eventWait<MealStartedEatingEvent>(),
        context.eventWait<MealBolusedEatingEvent>(),
      ]);
      print(
        "Handled meal started eating event ${mealStartedEvent.mealId} - starting monitoring",
      );

      final mealEatenEvent = await context.any([
        context.eventWait<MealFinishedEatingEvent>(),
        context.eventWait<MealFinishedEatingBolusedEvent>(),
      ]);
      print(
        "Handled meal finished event ${mealEatenEvent.mealId} stopping meal monitoring, waiting for next",
      );
    }
  }
}
