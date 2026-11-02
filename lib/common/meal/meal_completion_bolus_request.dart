import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';
import 'meal_activation_guard.dart';
import 'meal_add_on_bolus_context.dart';
import 'meal_bolus_coverage.dart';
import 'meal_completion_timing.dart';

bool mealCompletionRequiresDelivery({
  required int remainingCarbs,
  required bool hasRecordedBolus,
  required bool awaitingBolus,
}) => remainingCarbs > 0 && (hasRecordedBolus || awaitingBolus);

/// Keeps confirmed consumption open for the remaining delivered calculator
/// entry. Both summary entry points persist the same resumable waiting state.
Future<bool> persistMealCompletionBolusRequest(
  DatabaseImpl db, {
  required int mealId,
  required String currentStatus,
  required MealCompletionTiming timing,
  required DateTime endedAt,
  required MealBolusCoverage coverage,
  required MealAddOnBolusContext? previousContext,
  required int remainingCarbs,
  required int totalExtendedCarbs,
  required int extendedCarbsDelta,
}) => db.transaction(() async {
  await ensureMealActivationAllowed(
    db,
    mealId,
    allowedStatuses: {currentStatus, 'waiting-for-bolus'},
  );
  if (!await db.mealDao.tryUpdateMealStatus(
    mealId,
    'waiting-for-bolus',
    occurredAt: endedAt,
  )) {
    return false;
  }
  final previousRequest = previousContext?.awaitingBolus == true
      ? previousContext
      : null;
  final requestedAt = previousRequest?.requestedAt ?? clock.now();
  final pending = MealAddOnBolusContext(
    originalStatus: previousContext?.originalStatus ?? currentStatus,
    eatingStartedAt: previousContext?.eatingStartedAt ?? timing.startedAt,
    requestedAt: requestedAt,
    bolusWindowStartedAt: previousRequest?.bolusWindowStartedAt ?? requestedAt,
    coveredCarbs: coverage.carbs,
    statusCoveredCarbs:
        previousContext?.statusCoveredCarbs ?? coverage.statusBaselineCarbs,
    reportedExtendedCarbs: totalExtendedCarbs,
    requestedCarbs: remainingCarbs,
    requestedExtendedCarbs: extendedCarbsDelta,
    awaitingBolus: true,
    bolusConfirmed: coverage.hasRecordedBolus,
    acceptedWizardKeys: previousContext?.acceptedWizardKeys ?? const [],
  );
  await (db.update(db.meal)..where((row) => row.id.equals(mealId))).write(
    MealCompanion(
      consumptionConfirmedEndedAt: Value(endedAt.millisecondsSinceEpoch),
      addOnBolusContext: Value(pending.encode()),
    ),
  );
  return true;
});
