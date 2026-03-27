import '../../../../event/internal/meal_status_changed_event.dart';
import '../executors/bolus_then_wait_executor.dart';
import '../executors/detect_finished_eating_executor.dart';
import '../executors/finalize_meal_executor.dart';
import '../executors/idle_executor.dart';
import '../executors/meal_monitor_state_executor.dart';
import '../executors/monitor_until_meal.dart';

MealMonitorStateExecutor? mealStatusChangedEventToExecutor(
    MealStatusChangedEvent event,
    bool eventForActiveMeal,
    ) {
  return event.map(
    eating: (MealStartedEatingEvent value) =>
        DetectFinishedEatingExecutor(shouldBolus: false, bolusWaited: true),
    eaten: (MealFinishedEatingEvent value) => FinalizeMealExecutor(),
    skipped: (MealSkippedEvent value) {
      if (eventForActiveMeal) {
        return MealMonitorStateIdle();
      }
      // ignore this transition
      return null;
    },
    eatingThenBolus: (MealEatingThenBolus value) =>
        DetectFinishedEatingExecutor(shouldBolus: true),
    bolusedWaiting: (MealBolusedWaitingEvent value) =>
        BolusThenWaitExecutor(recommendedMinutes: null),
    bolusedEating: (MealBolusedEatingEvent value) =>
        DetectFinishedEatingExecutor(shouldBolus: false),
    eatenBolused: (MealFinishedEatingBolusedEvent value) =>
        FinalizeMealExecutor(),
    planned: (MealPlannedEvent value) => MonitorUntilMeal(),
    waitedEating: (WaitedEatingEvent value) => DetectFinishedEatingExecutor(shouldBolus: false, bolusWaited: true),
  );
}