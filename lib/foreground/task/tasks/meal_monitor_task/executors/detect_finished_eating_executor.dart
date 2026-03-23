import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../../event/internal/treatment_available_event.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'finalize_meal_executor.dart';
import 'idle_executor.dart';
import 'meal_monitor_state_executor.dart';

class DetectFinishedEatingExecutor extends MealMonitorStateExecutor with Logging {
  final bool shouldBolus;
  final bool? bolusWaited;
  final int? grams;

  DetectFinishedEatingExecutor({required this.shouldBolus, this.grams, this.bolusWaited});

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("DetectFinishedEatingExecutor cleanup");
  }

  @override
  Future<MealMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    MealMonitorContext mealMonitorContext,
  ) async {
    logI("DetectFinishedEatingExecutor");

    if (bolusWaited == null) {
      if (shouldBolus) {
        logI("Should bolus");
      } else {
        logI("Should not bolus");
        logI("Waiting for calculator use before moving to next step");
        final calculatorResponse = await runtimeContext
            .waitForEventWithTimeoutOrNull<TreatmentAvailableEvent<Meal>>(
          Duration(minutes: 20),
        );

        if (calculatorResponse == null) {
          logI("Problem gathering calculator response, going to idle state");
          return MealMonitorStateIdle();
        }

        logI("Calculator response available");
        runtimeContext.container.read(
          updateMealProvider(mealMonitorContext.activeMeal!, 'bolused-eating'),
        );
      }
    }


    await runtimeContext.waitForDuration(Duration(minutes: 5));

    logI ("Finished eating");

    return FinalizeMealExecutor();
  }
}
