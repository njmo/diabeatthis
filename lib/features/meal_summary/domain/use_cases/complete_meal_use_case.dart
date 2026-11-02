import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../common/meal/meal_completion_bolus_request.dart';
import '../../../../common/meal/meal_completion_decision.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../common/notifications/meal_completion_notification_cleanup.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/database_impl.dart' show MealCompanion;
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../presentation/models/meal_completion_choice.dart';
import '../../presentation/models/meal_summary_draft.dart';
import '../../presentation/utils/meal_summary_carbs_delta.dart';
import '../utils/meal_completion_amounts.dart';
import 'finalize_meal_summary_use_case.dart';
import 'persist_meal_summary_amounts.dart';

final completeMealUseCaseProvider = Provider<CompleteMealUseCase>(
  (ref) => CompleteMealUseCase(ref),
);

class MealCompletionResult {
  const MealCompletionResult({
    required this.meal,
    required this.requiresBolus,
    required this.consumedCarbs,
    required this.endedAt,
    this.consumedExtendedCarbs = 0,
    this.aapsCarbs,
  });

  final Meal meal;
  final bool requiresBolus;
  final int consumedCarbs;
  final int consumedExtendedCarbs;
  final MealSummaryAapsCarbs? aapsCarbs;
  final DateTime endedAt;
}

class CompleteMealUseCase {
  const CompleteMealUseCase(this.ref);

  final Ref ref;

  Future<MealCompletionResult> call({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) => complete(draft: draft, choice: choice, endedAt: endedAt);

  Future<MealCompletionResult> completeRefill({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) => complete(
    draft: draft,
    choice: choice,
    endedAt: endedAt,
    finishingRefill: true,
  );

  Future<MealCompletionResult> complete({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
    bool finishingRefill = false,
  }) async {
    if (!mealCompletionAmountsValid(draft, choice)) {
      throw MealSummaryCannotFinishException(lang.mealCompletionInvalidAmount);
    }
    final db = ref.read(databaseProvider);
    final result = await db.transaction(() async {
      final meal = await db.mealDao.getMealById(draft.mealId);
      if (meal == null ||
          meal.status != draft.mealStatus ||
          !(mealStatusesStartingEating.contains(meal.status) ||
              meal.status == 'eating-extra' ||
              mealStatusReadyToSummarize(meal.status))) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      if (finishingRefill) {
        try {
          await ensureMealActivationAllowed(
            db,
            draft.mealId,
            allowedStatuses: {meal.status},
          );
        } on MealActivationException catch (error) {
          throw MealSummaryCannotFinishException(error.userMessage);
        }
      }
      final currentItems = await db.mealIngredientsDao
          .getMealIngredientsForMeal(draft.mealId);
      if (currentItems.length != draft.itemsById.length ||
          currentItems.any((item) {
            final original = draft.itemsById[item.id];
            return original == null ||
                ((item.consumedAmount ?? item.amount) - original.reportedAmount)
                        .abs() >
                    0.001;
          })) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      final history = await (db.select(
        db.mealStatusHistory,
      )..where((row) => row.mealId.equals(draft.mealId))).get();
      final addOn = await reconcileMealAddOnBolusProgress(db, meal.id);
      final recordedTiming = MealCompletionTiming.fromHistory(
        history.map(
          (entry) => (
            status: entry.status,
            at: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
          ),
        ),
        currentStatus: meal.status,
      );
      final timing = addOn == null
          ? recordedTiming
          : MealCompletionTiming(
              startedAt: addOn.eatingStartedAt,
              endedAt: recordedTiming.endedAt,
              endStatus: recordedTiming.endStatus,
              isAddOn: true,
            );
      if (!timing.isValidEnd(endedAt, clock.now())) {
        throw MealSummaryCannotFinishException(lang.mealCompletionInvalidTime);
      }
      final coverage = await readMealBolusCoverage(db, meal.id, context: addOn);
      final reviewedCoverage = draft.reviewedBolusCoverage;
      if (reviewedCoverage != null &&
          (reviewedCoverage.carbs != coverage.carbs ||
              reviewedCoverage.hasRecordedBolus != coverage.hasRecordedBolus)) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      final before = await db.ingredientDao.totalsForMealConsumed(meal.id);
      await persistMealSummaryAmounts(ref, draft);
      ref.invalidate(getMealIngredientsDraftForMealProvider(draft.mealId));
      ref.invalidate(mealMacronutrientsConsumedSummaryProvider(draft.mealId));
      final totals = await db.ingredientDao.totalsForMealConsumed(meal.id);
      final correctionChoice = draft.correctionChoice;
      if (correctionChoice != null) {
        final reportedCarbs = before?.netCarbsGrams ?? 0.0;
        final consumedCarbs = totals?.netCarbsGrams ?? 0.0;
        final decision = MealCompletionDecision(
          choice: correctionChoice,
          recordedAt: clock.now(),
          eatingEndedAt: endedAt,
          reportedCarbs: reportedCarbs,
          consumedCarbs: consumedCarbs,
          proposedCorrectionCarbs: math.min(
            0,
            (consumedCarbs - reportedCarbs).ceil(),
          ),
        );
        await (db.update(db.meal)..where((row) => row.id.equals(meal.id)))
            .write(MealCompanion(completionDecision: Value(decision.encode())));
      }
      final remainingCarbs = math
          .max(0, (totals?.netCarbsGrams ?? 0) - coverage.carbs)
          .ceil();
      final totalExtendedCarbs = mealExtendedCarbsFromMacros(totals);
      final extendedCarbsDelta = math.max(
        0,
        totalExtendedCarbs -
            (addOn?.reportedExtendedCarbs ??
                mealExtendedCarbsFromMacros(before)),
      );
      final requiresBolus = mealCompletionRequiresDelivery(
        remainingCarbs: remainingCarbs,
        hasRecordedBolus: coverage.hasRecordedBolus,
        awaitingBolus:
            meal.status == 'eating-then-bolus' ||
            (addOn?.awaitingBolus ?? false),
      );
      final alreadyEnded = mealStatusReadyToSummarize(meal.status);
      final endStatus = alreadyEnded
          ? timing.endStatus ?? meal.status
          : requiresBolus
          ? 'waiting-for-bolus'
          : meal.status == 'eating-extra'
          ? 'eaten-extra'
          : 'eaten';

      if (alreadyEnded) {
        await db.mealDao.updateMealStatusHistoryTime(
          draft.mealId,
          endStatus,
          endedAt,
        );
      } else {
        await db.mealDao.updateMealStatus(
          draft.mealId,
          endStatus,
          occurredAt: endedAt,
        );
      }
      await ref
          .read(mealSnapshotControllerProvider)
          .saveConsumedSnapshot(draft.mealId);
      if (requiresBolus) {
        try {
          if (!await persistMealCompletionBolusRequest(
            db,
            mealId: meal.id,
            currentStatus: meal.status,
            timing: timing,
            endedAt: endedAt,
            coverage: coverage,
            previousContext: addOn,
            remainingCarbs: remainingCarbs,
            totalExtendedCarbs: totalExtendedCarbs,
            extendedCarbsDelta: extendedCarbsDelta,
          )) {
            throw MealSummaryCannotFinishException(lang.mealCompletionStale);
          }
        } on MealActivationException catch (error) {
          throw MealSummaryCannotFinishException(error.userMessage);
        }
      } else {
        await db.mealDao.updateMealStatus(draft.mealId, 'summarized');
      }
      return MealCompletionResult(
        meal: meal.toDomain(),
        requiresBolus: requiresBolus,
        consumedCarbs: (totals?.netCarbsGrams ?? 0).ceil(),
        consumedExtendedCarbs: totalExtendedCarbs,
        aapsCarbs: MealSummaryAapsCarbs(
          carbs: requiresBolus || coverage.hasRecordedBolus
              ? remainingCarbs
              : 0,
          extendedCarbs:
              requiresBolus ||
                  coverage.hasRecordedBolus ||
                  addOn != null ||
                  meal.status == 'eating-then-bolus'
              ? extendedCarbsDelta
              : 0,
        ),
        endedAt: endedAt,
      );
    });
    await ref
        .read(mealCompletionNotificationCleanupProvider)
        .call(draft.mealId, requiresBolus: result.requiresBolus);
    return result;
  }
}
