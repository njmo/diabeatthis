import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
import '../../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../common/meal/meal_completion_bolus_request.dart';
import '../../../../common/meal/meal_completion_timing.dart';
import '../../../../common/meal/meal_extended_carbs.dart';
import '../../../../common/notifications/meal_completion_notification_cleanup.dart';
import '../../../../common/notifications/meal_notification_cancellation.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../presentation/models/meal_summary_draft.dart';
import '../utils/meal_add_on_status.dart';
import 'persist_meal_summary_amounts.dart';

part 'finalize_meal_summary_use_case.g.dart';

@Riverpod(keepAlive: true)
FinalizeMealSummaryUseCase finalizeMealSummaryUseCase(Ref ref) {
  return FinalizeMealSummaryUseCase(ref: ref);
}

enum MealSummarySaveMode { finishMeal, continueEating }

class MealSummaryCannotFinishException implements Exception {
  const MealSummaryCannotFinishException(this.userMessage);

  final String userMessage;
}

bool mealSummaryRequiresBolusBeforeFinish(String? status) {
  return status == 'eating-then-bolus' ||
      status == 'waiting-for-bolus' ||
      status == 'bolused-eating' ||
      status == 'bolused-waiting';
}

bool mealSummaryCanFinish(String? status) {
  return status == 'eaten' ||
      status == 'eaten-extra' ||
      status == 'eaten-bolused';
}

class FinalizeMealSummaryUseCase with Logging {
  final Ref ref;
  FinalizeMealSummaryUseCase({required this.ref});

  Future<void> call(
    MealSummaryDraft draft, {
    MealSummarySaveMode mode = MealSummarySaveMode.finishMeal,
  }) async {
    final db = ref.read(databaseProvider);
    final snapshotController = ref.read(mealSnapshotControllerProvider);
    final notificationsController = ref.read(notificationsControllerUiProvider);
    var requiresBolus = false;

    if (mode == MealSummarySaveMode.finishMeal &&
        !mealSummaryCanFinish(draft.mealStatus)) {
      throw MealSummaryCannotFinishException(
        mealSummaryRequiresBolusBeforeFinish(draft.mealStatus)
            ? lang.uiFirstGiveTheBolusUsingTheCalculatorThenFinish
            : lang.uiFirstMarkTheMealAsEatenThenSaveThe,
      );
    }

    await db.transaction(() async {
      final meal = await db.mealDao.getMealById(draft.mealId);
      if (meal == null ||
          meal.status != draft.mealStatus ||
          !(mealSummaryCanFinish(meal.status) ||
              mealStatusesStartingEating.contains(meal.status) ||
              meal.status == 'eating-extra' ||
              meal.status == 'summarized')) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
      if (mode == MealSummarySaveMode.continueEating) {
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
      final addOn = mode == MealSummarySaveMode.finishMeal
          ? await reconcileMealAddOnBolusProgress(db, meal.id)
          : null;
      final coverage = mode == MealSummarySaveMode.finishMeal
          ? await readMealBolusCoverage(db, meal.id, context: addOn)
          : null;
      final before = mode == MealSummarySaveMode.finishMeal
          ? await db.ingredientDao.totalsForMealConsumed(meal.id)
          : null;
      await persistMealSummaryAmounts(ref, draft);
      ref.invalidate(getMealIngredientsDraftForMealProvider(draft.mealId));
      ref.invalidate(mealMacronutrientsConsumedSummaryProvider(draft.mealId));

      if (mode == MealSummarySaveMode.finishMeal) {
        await snapshotController.saveConsumedSnapshot(draft.mealId);
        final totals = await db.ingredientDao.totalsForMealConsumed(meal.id);
        final remainingCarbs = math
            .max(0, (totals?.netCarbsGrams ?? 0) - coverage!.carbs)
            .ceil();
        requiresBolus = mealCompletionRequiresDelivery(
          remainingCarbs: remainingCarbs,
          hasRecordedBolus: coverage.hasRecordedBolus,
          awaitingBolus: addOn?.awaitingBolus ?? false,
        );
        if (requiresBolus) {
          final history = await (db.select(
            db.mealStatusHistory,
          )..where((row) => row.mealId.equals(meal.id))).get();
          final timing = MealCompletionTiming.fromHistory(
            history.map(
              (entry) => (
                status: entry.status,
                at: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
              ),
            ),
            currentStatus: meal.status,
          );
          final totalExtendedCarbs = mealExtendedCarbsFromMacros(totals);
          late final bool saved;
          try {
            saved = await persistMealCompletionBolusRequest(
              db,
              mealId: meal.id,
              currentStatus: meal.status,
              timing: timing,
              endedAt: timing.endedAt ?? clock.now(),
              coverage: coverage,
              previousContext: addOn,
              remainingCarbs: remainingCarbs,
              totalExtendedCarbs: totalExtendedCarbs,
              extendedCarbsDelta: math.max(
                0,
                totalExtendedCarbs -
                    (addOn?.reportedExtendedCarbs ??
                        mealExtendedCarbsFromMacros(before)),
              ),
            );
          } on MealActivationException catch (error) {
            throw MealSummaryCannotFinishException(error.userMessage);
          }
          if (!saved) {
            throw MealSummaryCannotFinishException(lang.mealCompletionStale);
          }
          return;
        }
      }

      final status = mode == MealSummarySaveMode.finishMeal
          ? 'summarized'
          : mealStatusAfterAddOn(meal.status);
      if (!await db.mealDao.tryUpdateMealStatus(draft.mealId, status)) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
    });
    if (requiresBolus) {
      await ref
          .read(mealCompletionNotificationCleanupProvider)
          .call(draft.mealId, requiresBolus: true);
      return;
    }
    // A committed summary must not be retried because notification cleanup failed.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await notificationsController.cancelMealNotifications(
          draft.mealId,
          includeTargetConsent: mode == MealSummarySaveMode.finishMeal,
          includeBolusInstructions: mode == MealSummarySaveMode.finishMeal,
        );
        break;
      } catch (error, stackTrace) {
        logE(
          'Meal summary notification cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
