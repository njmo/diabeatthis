import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../presentation/models/meal_summary_draft.dart';
import 'add_meal_extra_item_use_case.dart';

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
            ? 'Najpierw podaj bolusa w kalkulatorze. Dopiero potem zakończ posiłek.'
            : 'Najpierw oznacz posiłek jako zjedzony. Dopiero potem zapisz podsumowanie.',
      );
    }

    await notificationsController.cancelAll();

    await db.transaction(() async {
      for (final item in draft.itemsById.values) {
        await db.mealIngredientsDao.updateMealIngredientConsumed(
          item.mealIngredientId,
          item.consumedAmount,
          item.consumedConfidence,
        );
      }

      for (final mealIngredient in draft.extraItems) {
        await ref
            .read(addMealExtraItemUseCaseProvider)
            .call(
              mealId: draft.mealId,
              mealIngredient: mealIngredient,
              statusAfterAdd: null,
            );
      }

      if (mode == MealSummarySaveMode.finishMeal) {
        await snapshotController.saveConsumedSnapshot(draft.mealId);
      }

      final status = mode == MealSummarySaveMode.finishMeal
          ? 'summarized'
          : 'eating-extra';
      await ref.read(updateMealByIdProvider(draft.mealId, status).future);
    });
  }
}
