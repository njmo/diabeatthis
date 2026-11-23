import '../../../../../common/meal/calculator/meal_calculator_request_controller.dart';
import '../../../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../../common/meal/meal_calculator_submission.dart';
import '../../../../../common/meal/meal_treatment_surplus.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../features/meals/common/models/meal_wizard_relation_type.dart';
import '../../../../../features/meals/data/repositories/meal_wizard_link_repository.dart';
import '../../../../providers/calculator_submissions_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_bolus_delivery_changed.dart';
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
  BolusWizard first, {
  List<BolusWizard> previouslyAccepted = const [],
}) async {
  final required = await _calculator(
    runtime,
  )?.requiredMealCarbs(meal.activeMeal!.id);
  meal.throwIfStopped(runtime);
  var accepted = [...previouslyAccepted];
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
  while (true) {
    accepted = await _currentUnassignedDeliveries(runtime, accepted);
    meal.throwIfStopped(runtime);
    final total = _totalCarbs(accepted);
    if (required == null ? accepted.isNotEmpty : total >= required - 0.001) {
      return accepted;
    }
    final acceptedAt = accepted
        .map((wizard) => wizard.createdAt.millisecondsSinceEpoch)
        .toSet();
    final submission = await const WaitForMealBolusDelivery()(
      runtime,
      meal,
      anchor,
      requireRecordedBolus: false,
      acceptsWizard: required == null
          ? null
          : (wizard) =>
                wizard.carbs.isFinite &&
                wizard.carbs > 0 &&
                !acceptedAt.contains(wizard.createdAt.millisecondsSinceEpoch),
    );
    accepted.add(submission.wizard);
  }
}

double _totalCarbs(List<BolusWizard> wizards) =>
    wizards.fold(0.0, (total, wizard) => total + wizard.carbs);

Future<List<BolusWizard>> _currentUnassignedDeliveries(
  RuntimeContext runtime,
  List<BolusWizard> accepted, {
  bool requireUnassigned = true,
}) async {
  if (accepted.isEmpty || !runtime.container.exists(databaseProvider)) {
    return accepted;
  }
  final db = runtime.container.read(databaseProvider);
  if (!db.hasOpened) return accepted;
  final live = runtime.container.read(calculatorSubmissionsProvider.notifier);
  final current = <BolusWizard>[];
  for (final wizard in accepted) {
    final records = await db.localMirrorDao.getBolusWizardsBetween(
      wizard.createdAt,
      wizard.createdAt,
    );
    if (records.isEmpty ||
        (requireUnassigned &&
            await mealBolusWizardAlreadyAssigned(db, wizard))) {
      continue;
    }
    final submission = await readMealCalculatorSubmission(
      db,
      records.single.toDomain(),
      liveTreatments: live.records,
    );
    if (submission.isValid &&
        (submission.isComplete ||
            (submission.wizard.remoteSource == null &&
                !submission.hasUnresolvedDelivery &&
                !submission.wizard.hasUnresolvedDelivery &&
                submission.recommendedInsulin.isFinite &&
                submission.recommendedInsulin > 0))) {
      current.add(submission.wizard.copyWith(localId: records.single.localId));
    }
  }
  return current;
}

/// Writes links and the phase together, or returns false if the evidence has
/// changed while the monitor was waiting for the rest of the meal entries.
Future<bool?> commitMealBolusDeliveries(
  RuntimeContext runtime,
  MealMonitorContext meal,
  List<BolusWizard> accepted,
  String nextStatus,
) async {
  if (!runtime.container.exists(databaseProvider)) return null;
  final db = runtime.container.read(databaseProvider);
  if (!db.hasOpened) return null;
  final active = meal.activeMeal!;
  final required = await _calculator(runtime)?.requiredMealCarbs(active.id);
  try {
    return await db.transaction(() async {
      final savedMeal = await db.mealDao.getMealById(active.id);
      if (savedMeal?.status != 'waiting-for-bolus') return false;
      final current = await _currentUnassignedDeliveries(runtime, accepted);
      final total = _totalCarbs(current);
      if (current.length != accepted.length ||
          (required != null && total < required - 0.001)) {
        return false;
      }
      meal.throwIfStopped(runtime);
      for (final (index, wizard) in current.indexed) {
        await MealWizardLinkRepository(db).link(
          mealId: active.id,
          localWizardId: wizard.localId!,
          remoteWizardId: wizard.remoteSource == null
              ? null
              : wizard.nightscoutObjectId,
          remoteSource: wizard.nightscoutObjectId == null
              ? null
              : wizard.remoteSource,
          relationType: index == 0
              ? MealWizardRelationType.initial
              : MealWizardRelationType.continuation,
        );
      }
      if (required != null && total > required + 0.001) {
        await recordMealTreatmentSurplus(db, active.id);
      }
      meal.throwIfStopped(runtime);
      if (!await db.mealDao.tryUpdateMealStatus(active.id, nextStatus)) {
        throw const MealBolusDeliveryChanged();
      }
      final latest = await _currentUnassignedDeliveries(
        runtime,
        current,
        requireUnassigned: false,
      );
      if (latest.length != current.length || _totalCarbs(latest) != total) {
        throw const MealBolusDeliveryChanged();
      }
      return true;
    });
  } on MealBolusDeliveryChanged {
    return false;
  }
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
