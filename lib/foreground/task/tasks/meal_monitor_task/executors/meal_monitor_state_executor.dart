import '../../../../../core/logger/logger.dart';
import '../../../../event/internal/meal_event.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';

abstract class MealMonitorStateExecutor with Logging {
  String get name => runtimeType.toString();

  List<Type> get interruptableEvents => [
    MealStartedEatingEvent,
    MealEatingExtraEvent,
    MealEatingThenBolus,
    MealWaitingForBolusEvent,
    MealBolusedEatingEvent,
    MealBolusedWaitingEvent,
    MealSkippedEvent,
    NextMealEvent,
  ];

  // For example to check whether event applies to current active meal
  // to avoid situation that event skipped for some random meal will
  // cause interruption to the currently active executor.
  bool shouldInterrupt(
    ForegroundEvent event,
    MealMonitorContext mealMonitorContext,
  ) {
    logI("MealMonitorStateExecutor shouldInterrupt ${event.runtimeType}");
    return true;
  }

  const MealMonitorStateExecutor();

  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  );
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  );
}
