import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/data_sources/config/data_source_config.dart';
import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/domain/model/bolus_wizard.dart' as domain;
import '../../core/drift/database_impl.dart';
import '../../core/drift/helpers/validate_wizard_identity.dart';
import '../nutrition/stable_macro_ceil.dart';
import 'meal_add_on_bolus_context.dart';
import 'meal_bolus_coverage.dart';
import 'meal_calculator_submission.dart';
import 'meal_completion_timing.dart';
import 'meal_extended_carbs.dart';

Future<MealAddOnBolusContext?> readMealAddOnBolusContext(
  DatabaseImpl db,
  int mealId,
) async => MealAddOnBolusContext.decode(
  (await db.mealDao.getMealById(mealId))?.addOnBolusContext,
);

bool mealAddOnAcceptsWizard(
  MealAddOnBolusContext context,
  domain.BolusWizard wizard,
) =>
    wizard.isValid &&
    wizard.carbs.isFinite &&
    wizard.carbs > 0 &&
    wizard.createdAt.millisecondsSinceEpoch ~/ 1000 >=
        context.bolusWindowStartedAt.millisecondsSinceEpoch ~/ 1000 &&
    !context.acceptedWizardKeys.contains(mealBolusWizardKey(wizard)) &&
    !context.acceptedWizardKeys.contains(
      'at:${wizard.createdAt.millisecondsSinceEpoch}',
    );

/// Confirms only the still-current request against persisted completion evidence.
/// The meal link and coverage commit together so a restart cannot lose the relation.
Future<MealAddOnBolusContext?> acceptMealAddOnBolus(
  DatabaseImpl db,
  int mealId,
  domain.BolusWizard wizard, {
  required DateTime requestedAt,
}) => db.transaction(() async {
  final meal = await db.mealDao.getMealById(mealId);
  if (meal == null ||
      !const {
        'eating-extra',
        'eating-then-bolus',
        'waiting-for-bolus',
      }.contains(meal.status)) {
    return null;
  }
  final current = MealAddOnBolusContext.decode(meal.addOnBolusContext);
  if (current == null ||
      !current.awaitingBolus ||
      current.requestedAt != requestedAt ||
      !mealAddOnAcceptsWizard(current, wizard)) {
    return null;
  }
  final storedWizard =
      await (db.select(db.bolusWizard)..where(
            (row) =>
                row.createdAt.equals(wizard.createdAt.millisecondsSinceEpoch),
          ))
          .getSingleOrNull();
  // The delivery gate persists accepted evidence before calling this function.
  // A missing row can be an invalidation, never permission to resurrect a
  // previously confirmed in-memory snapshot.
  if (storedWizard == null) return null;
  final canonical = storedWizard.toDomain();
  if (!canonical.carbs.isFinite ||
      (canonical.carbs - wizard.carbs).abs() > 0.001) {
    return null;
  }
  final links = await db.mealWizardLinkDao.forWizardIds(
    localIds: [storedWizard.localId],
    remoteIds: storedWizard.nightscoutId == null
        ? []
        : [storedWizard.nightscoutId!],
  );
  if (links.isNotEmpty) return null;
  validateWizardIdentity(
    storedWizard,
    wizard.toCompanion(TreatmentsSource.fromStorage(storedWizard.source)),
  );
  if (!(await readMealCalculatorSubmission(db, canonical)).isComplete) {
    return null;
  }
  final coverage = await readMealBolusCoverage(db, mealId, context: current);
  final coveredCarbs = coverage.carbs + canonical.carbs;
  final totals = await db.ingredientDao.totalsForMealConsumed(mealId);
  final requestedCarbs = math
      .max(0, stableMacroDifference(totals?.netCarbsGrams ?? 0, coveredCarbs))
      .ceilMacro();
  final updated = current.copyWith(
    coveredCarbs: coveredCarbs,
    requestedCarbs: requestedCarbs,
    awaitingBolus: requestedCarbs > 0,
    bolusConfirmed: true,
    acceptedWizardKeys: {
      ...current.acceptedWizardKeys,
      mealBolusWizardKey(wizard),
      'at:${wizard.createdAt.millisecondsSinceEpoch}',
    }.toList(),
  );
  await db.mealWizardLinkDao.link(
    mealId: mealId,
    localWizardId: storedWizard.localId,
    relationType: current.bolusConfirmed ? 'continuation' : 'initial',
  );
  await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
    MealCompanion(addOnBolusContext: Value(updated.encode())),
  );
  return updated;
});

/// A calculator may have reached persistent storage before the foreground
/// listener. Reconcile it before presenting another request for the same meal.
Future<MealAddOnBolusContext?> reconcileMealAddOnBolusProgress(
  DatabaseImpl db,
  int mealId, {
  int? initialReportedExtendedCarbs,
}) => db.transaction(() async {
  final meal = await db.mealDao.getMealById(mealId);
  if (meal == null) return null;
  var context = MealAddOnBolusContext.decode(meal.addOnBolusContext);
  if (context == null && meal.status == 'eating-then-bolus') {
    final history = await (db.select(
      db.mealStatusHistory,
    )..where((row) => row.mealId.equals(mealId))).get();
    final start = MealCompletionTiming.fromHistory(
      history.map(
        (row) => (
          status: row.status,
          at: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        ),
      ),
      currentStatus: meal.status,
    ).startedAt;
    if (start != null) {
      final coverage = await readMealBolusCoverage(db, mealId);
      final totals = await db.ingredientDao.totalsForMealConsumed(mealId);
      final remaining = math
          .max(
            0,
            stableMacroDifference(totals?.netCarbsGrams ?? 0, coverage.carbs),
          )
          .ceilMacro();
      context = MealAddOnBolusContext(
        originalStatus: meal.status,
        eatingStartedAt: start,
        requestedAt: start,
        coveredCarbs: coverage.carbs,
        statusCoveredCarbs: coverage.statusBaselineCarbs,
        reportedExtendedCarbs:
            initialReportedExtendedCarbs ?? mealExtendedCarbsFromMacros(totals),
        requestedCarbs: remaining,
        requestedExtendedCarbs: 0,
        awaitingBolus: remaining > 0,
        bolusConfirmed: coverage.hasRecordedBolus,
      );
      await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
        MealCompanion(addOnBolusContext: Value(context.encode())),
      );
    }
  }
  if (!const {
    'eating-extra',
    'eating-then-bolus',
    'waiting-for-bolus',
  }.contains(meal.status)) {
    return context;
  }
  if (context == null) return context;
  var pending = context;
  final responseSince = pending.bolusWindowStartedAt.millisecondsSinceEpoch;
  final candidates =
      await (db.select(db.bolusWizard)
            ..where((row) => row.createdAt.isBiggerOrEqualValue(responseSince))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();
  for (final candidate in candidates) {
    if (!pending.awaitingBolus) break;
    final previous = pending;
    final accepted = await acceptMealAddOnBolus(
      db,
      mealId,
      candidate.toDomain(),
      requestedAt: previous.requestedAt,
    );
    if (accepted == null) continue;
    pending = accepted;
  }
  final coverage = await readMealBolusCoverage(db, mealId, context: pending);
  final totals = await db.ingredientDao.totalsForMealConsumed(mealId);
  final remaining = math
      .max(0, stableMacroDifference(totals?.netCarbsGrams ?? 0, coverage.carbs))
      .ceilMacro();
  final updated = pending.copyWith(
    coveredCarbs: coverage.carbs,
    requestedCarbs: remaining,
    awaitingBolus: remaining > 0,
    bolusConfirmed: coverage.hasRecordedBolus,
  );
  if (updated.encode() != pending.encode()) {
    await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
      MealCompanion(addOnBolusContext: Value(updated.encode())),
    );
  }
  return updated;
});
