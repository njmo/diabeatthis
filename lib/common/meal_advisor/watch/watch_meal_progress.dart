import '../../meal/meal_add_on_bolus_context.dart';
import '../../meal/meal_add_on_progress.dart';
import '../../meal/meal_decision.dart';
import '../../meal/meal_progress_plan.dart';

Map<String, Object?> watchMealProgress(
  String status, {
  MealDecision? decision,
  Iterable<String> history = const [],
  MealAddOnBolusContext? addOn,
  MealAddOnProgress? mirroredAddOn,
  DateTime? waitStartedAt,
  int? waitMinutes,
  DateTime? waitDeadline,
  int? carbs,
  int? extendedCarbs,
  bool carbsEntered = false,
  bool extendedCarbsConfirmed = false,
  bool waitingForExtendedCarbs = false,
}) {
  final progress = mealProgressPlanForStatus(
    status,
    decision: decision,
    history: history,
    addOn: addOn,
    mirroredAddOn: mirroredAddOn,
  );
  final stage = progress.currentStage;
  return {
    'stage': stage.name,
    if (progress.canFinishEating && status != 'bolused-waiting')
      'canFinishEating': true,
    // Starting to eat follows the status, not the wait clock: an eat-now meal
    // asks for this confirmation without a waiting stage or deadline.
    'canStartEating': status == 'bolused-waiting' && !waitingForExtendedCarbs,
    'index': progress.currentIndex,
    'count': progress.stages.length,
    'completed': [
      for (var i = 0; i < progress.stages.length; i++)
        if (progress.isComplete(i)) i,
    ],
    if (stage == MealProgressStage.waiting)
      if (waitDeadline ??
              (waitStartedAt != null && waitMinutes != null && waitMinutes > 0
                  ? waitStartedAt.add(Duration(minutes: waitMinutes))
                  : null)
          case final DateTime deadline)
        'waitUntilMs': deadline.millisecondsSinceEpoch,
    if (stage == MealProgressStage.bolus ||
        (stage == MealProgressStage.waiting && waitingForExtendedCarbs)) ...{
      if (waitingForExtendedCarbs) 'waitingForExtendedCarbs': true,
      if (carbs ?? addOn?.requestedCarbs case final int value) 'carbs': value,
      if (extendedCarbs ?? addOn?.requestedExtendedCarbs case final int value)
        'extendedCarbs': value,
      if (addOn == null
          ? carbsEntered
          : !addOn.awaitingBolus && addOn.bolusConfirmed)
        'carbsEntered': true,
      if (extendedCarbsConfirmed || addOn?.extendedCarbsConfirmed == true)
        'extendedCarbsConfirmed': true,
    },
  };
}
