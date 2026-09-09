import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../event/internal/meal_event.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_monitor_state_executor.dart';

class MealMonitorStateIdle extends MealMonitorStateExecutor with Logging {
  MealMonitorStateIdle({this.phase = MealMonitoringPhase.idle});

  final MealMonitoringPhase phase;

  @override
  List<Type> get interruptableEvents => [
    MealStartedEatingEvent,
    MealEatingExtraEvent,
    MealWaitingForBolusEvent,
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
    logI("MealMonitorStateIdle cleanup");
    return Future.value();
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    mealMonitorContext.publishStatus(runtimeContext, phase);
    logI("MealMonitorStateIdle");
    await runtimeContext.waitForDuration(Duration(minutes: 15));
    return this;
  }
}
