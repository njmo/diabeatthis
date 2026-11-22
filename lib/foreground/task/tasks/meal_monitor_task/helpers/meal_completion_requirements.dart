import '../../../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../../../../../common/meal/meal_treatment_surplus.dart';
import '../../../../../common/meal/calculator/meal_calculator_request_controller.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'wait_for_meal_bolus_delivery.dart';

const mealRequirementRefreshInterval = Duration(seconds: 5);

MealCalculatorRequestController? _calculator(RuntimeContext runtime) {
  final container = runtime.container;
  if (!container.exists(databaseProvider) &&
      !container.exists(mealCalculatorRequestControllerProvider)) {
    return null;
  }
  return container.read(mealCalculatorRequestControllerProvider);
}

Future<bool> mealHasPendingExtendedCarbs(
  RuntimeContext runtime,
  int mealId,
) async =>
    await _calculator(runtime)?.hasPendingScheduledExtendedCarbs(mealId) ??
    false;

Future<List<BolusWizard>> waitForMealCarbDeliveries(
  RuntimeContext runtime,
  MealMonitorContext meal,
  BolusWizard first,
) async {
  final required = await _calculator(
    runtime,
  )?.requiredMealCarbs(meal.activeMeal!.id);
  meal.throwIfStopped(runtime);
  final accepted = <BolusWizard>[];
  final acceptedAt = <int>{};
  var total = 0.0;
  final active = meal.activeMeal!;
  var anchor = first;
  if (required != null &&
      active.updatedAt != null &&
      runtime.container.exists(databaseProvider)) {
    final db = runtime.container.read(databaseProvider);
    if (db.hasOpened && active.updatedAt!.isBefore(first.createdAt)) {
      final persisted = await db.localMirrorDao.getBolusWizardsBetween(
        active.updatedAt!,
        first.createdAt,
      );
      anchor = persisted
          .map((row) => row.toDomain())
          .where(
            (wizard) =>
                wizard.isValid && wizard.carbs.isFinite && wizard.carbs > 0,
          )
          .fold(
            first,
            (earliest, candidate) =>
                candidate.createdAt.isBefore(earliest.createdAt)
                ? candidate
                : earliest,
          );
    }
  }
  do {
    final submission = await const WaitForMealBolusDelivery()(
      runtime,
      meal,
      anchor,
      acceptsWizard: required == null
          ? null
          : (wizard) =>
                wizard.carbs.isFinite &&
                wizard.carbs > 0 &&
                !acceptedAt.contains(wizard.createdAt.millisecondsSinceEpoch),
    );
    accepted.add(submission.wizard);
    acceptedAt.add(submission.wizard.createdAt.millisecondsSinceEpoch);
    total += submission.carbs;
  } while (required != null && total < required - 0.001);
  if (required != null &&
      total > required + 0.001 &&
      runtime.container.exists(databaseProvider)) {
    await recordMealTreatmentSurplus(
      runtime.container.read(databaseProvider),
      active.id,
    );
  }
  return accepted;
}

Future<void> waitForMealCompletionRequirements(
  RuntimeContext runtime,
  MealMonitorContext meal, {
  required Future<bool> Function() hasPendingRequirements,
}) async {
  while (true) {
    meal.throwIfStopped(runtime);
    final pending = await hasPendingRequirements();
    meal.throwIfStopped(runtime);
    if (!pending) return;
    await runtime.waitForDuration(mealRequirementRefreshInterval);
  }
}
