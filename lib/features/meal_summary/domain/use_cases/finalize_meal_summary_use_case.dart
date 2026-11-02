import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_activation_guard.dart';
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
      await persistMealSummaryAmounts(ref, draft);
      ref.invalidate(getMealIngredientsDraftForMealProvider(draft.mealId));
      ref.invalidate(mealMacronutrientsConsumedSummaryProvider(draft.mealId));

      if (mode == MealSummarySaveMode.finishMeal) {
        await snapshotController.saveConsumedSnapshot(draft.mealId);
      }

      final status = mode == MealSummarySaveMode.finishMeal
          ? 'summarized'
          : mealStatusAfterAddOn(meal.status);
      if (!await db.mealDao.tryUpdateMealStatus(draft.mealId, status)) {
        throw MealSummaryCannotFinishException(lang.mealCompletionStale);
      }
    });
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
