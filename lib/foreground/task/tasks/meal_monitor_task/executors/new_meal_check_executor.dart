import 'package:clock/clock.dart';

import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/meal_status_changed_event.dart';
import '../../../base/runtime_context.dart';
import '../helpers/meal_status_to_executor_mapper.dart';
import '../meal_monitor_context.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class NewMealCheckExecutor extends MealMonitorStateExecutor with Logging {
  NewMealCheckExecutor();

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("NewMealCheckExecutor cleanup");
  }

  Future<Meal?> checkForNextMeal(RuntimeContext context) async {
    final meal = await context.container.read(getNearestMealProvider.future);
    return meal;
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("NewMealCheckExecutor");

    final nextMeal = await checkForNextMeal(runtimeContext);
    if (nextMeal == null) {
      logI("No meal to monitor, wait for NextMealEvent and sleep.");
      // no meal to monitor, wait for NextMealEvent and sleep.
      return MealMonitorStateIdle();
    }

    if (nextMeal.plannedAt!.isAfter(clock.now())) {
      // map status to proper event
      final mealStateEvent = MealStatusChangedEvent.fromMealStatus(nextMeal);
      final nextExecutor = mealStatusChangedEventToExecutor(
        mealStateEvent,
        true,
      );

      mealMonitorContext.activeMeal = nextMeal;
      return nextExecutor ?? MealMonitorStateIdle();
    }

    return MealMonitorStateIdle();
  }
}
