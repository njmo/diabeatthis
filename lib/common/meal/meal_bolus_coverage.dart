import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/domain/model/bolus_wizard.dart' as domain;
import '../../core/drift/database_impl.dart';
import 'meal_add_on_bolus_context.dart';
import 'meal_bolus_evidence.dart';
import 'meal_calculator_submission.dart';

class MealBolusCoverage {
  const MealBolusCoverage({
    required this.carbs,
    required this.hasRecordedBolus,
    required this.statusBaselineCarbs,
  });

  final double carbs;
  final bool hasRecordedBolus;
  final double statusBaselineCarbs;
}

/// Reads accepted calculator submissions with independent completion evidence,
/// never ingredient amounts as evidence of a bolus. Legacy confirmed statuses
/// without a linked calculator retain their
/// original planned/confirmed meal amount as the initial baseline.
Future<MealBolusCoverage> readMealBolusCoverage(
  DatabaseImpl db,
  int mealId, {
  MealAddOnBolusContext? context,
}) async {
  final meal = await db.mealDao.getMealById(mealId);
  final history = await (db.select(
    db.mealStatusHistory,
  )..where((row) => row.mealId.equals(mealId))).get();
  final hasStatusEvidence = mealHasRecordedBolus(
    currentStatus: meal?.status,
    history: history.map((row) => row.status),
  );
  final links = await db.mealWizardLinkDao.forMeal(mealId);
  final hasTrackedSubmissions =
      links.isNotEmpty || (context?.acceptedWizardKeys.isNotEmpty ?? false);
  var hasInitial = false;
  var hasWizard = false;
  var linkedCarbs = 0.0;
  for (final link in links) {
    if (link.relationType == 'correction') continue;
    final wizard =
        await (db.select(db.bolusWizard)..where((row) {
              if (link.localWizardId != null) {
                return row.localId.equals(link.localWizardId!);
              }
              return row.nightscoutId.equals(link.remoteWizardId!) &
                  row.remoteSource.equals(link.remoteSource!);
            }))
            .getSingleOrNull();
    if (wizard == null) continue;
    if (!(await readMealCalculatorSubmission(
      db,
      wizard.toDomain(),
    )).isComplete) {
      continue;
    }
    hasInitial |= link.relationType == 'initial';
    hasWizard = true;
    final amount = wizard.carbs;
    if (amount != null && amount.isFinite && amount > 0) linkedCarbs += amount;
  }
  var statusBaselineCarbs = 0.0;
  if (!hasInitial && hasTrackedSubmissions) {
    statusBaselineCarbs = context?.statusCoveredCarbs ?? 0;
    linkedCarbs += statusBaselineCarbs;
  } else if (!hasInitial && hasStatusEvidence) {
    final snapshot =
        await (db.select(db.mealSnapshot)..where(
              (row) =>
                  row.mealId.equals(mealId) &
                  row.snapshotType.equals('consumed'),
            ))
            .getSingleOrNull();
    final planned = await db.ingredientDao.totalsForMeal(mealId);
    statusBaselineCarbs =
        context?.statusCoveredCarbs ??
        snapshot?.totalNetCarbsG ??
        planned?.netCarbsGrams ??
        0;
    linkedCarbs += statusBaselineCarbs;
  }
  return MealBolusCoverage(
    carbs: hasTrackedSubmissions
        ? linkedCarbs
        : math.max(linkedCarbs, context?.coveredCarbs ?? 0),
    hasRecordedBolus:
        hasWizard ||
        (hasTrackedSubmissions
            ? statusBaselineCarbs > 0
            : hasStatusEvidence || (context?.bolusConfirmed ?? false)),
    statusBaselineCarbs: statusBaselineCarbs,
  );
}

String mealBolusWizardKey(domain.BolusWizard wizard) {
  if (wizard.localId != null) return 'local:${wizard.localId}';
  if (wizard.remoteSource != null && wizard.nightscoutObjectId != null) {
    return 'remote:${wizard.remoteSource}:${wizard.nightscoutObjectId}';
  }
  return 'at:${wizard.createdAt.millisecondsSinceEpoch}';
}

Future<bool> mealBolusWizardAlreadyAssigned(
  DatabaseImpl db,
  domain.BolusWizard wizard,
) async {
  final stored =
      await (db.select(db.bolusWizard)..where(
            (row) =>
                row.createdAt.equals(wizard.createdAt.millisecondsSinceEpoch),
          ))
          .getSingleOrNull();
  if (stored == null) return false;
  return (await db.mealWizardLinkDao.forWizardIds(
    localIds: [stored.localId],
    remoteIds: stored.nightscoutId == null ? [] : [stored.nightscoutId!],
  )).isNotEmpty;
}
