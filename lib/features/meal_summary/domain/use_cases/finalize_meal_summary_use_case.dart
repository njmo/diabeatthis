import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../presentation/models/meal_summary_draft.dart';

part 'finalize_meal_summary_use_case.g.dart';

@Riverpod(keepAlive: true)
FinalizeMealSummaryUseCase finalizeMealSummaryUseCase(Ref ref) {
  return FinalizeMealSummaryUseCase(ref: ref);
}

class FinalizeMealSummaryUseCase with Logging {
  final Ref ref;
  FinalizeMealSummaryUseCase({required this.ref});

  Future<void> call(MealSummaryDraft draft) async {
    final db = ref.read(databaseProvider);
    final snapshotController = ref.read(mealSnapshotControllerProvider);

    await db.transaction(() async {
      for (final item in draft.itemsById.values) {
        await db.mealIngredientsDao.updateMealIngredientConsumed(
          item.mealIngredientId,
          item.consumedAmount,
          item.consumedConfidence,
        );
      }

      for (final mealIngredient in draft.extraItems) {
        final ingredient = await ref.read(
          insertIngredientProvider(mealIngredient.ingredient).future,
        );
        logI("Added ${(ingredient).name}");
        final portion = await ref.read(
          insertPortionProvider(
            mealIngredient.ingredientPortion.portion,
          ).future,
        );

        logI("Added ${portion?.name ?? 'no portion'}");
        logI("Adding ingredient portion relation");
        await ref.read(
          insertIngredientPortionProvider(
            ingredient,
            portion,
            mealIngredient.ingredientPortion.amount,
          ).future,
        );
        await ref.read(
          insertExtraMealIngredientProvider(
            ingredient,
            draft.mealId,
            portion,
            mealIngredient.amount,
            mealIngredient.quantityConfidence,
          ).future,
        );
        logI("Added meal ingredient");
      }

      await snapshotController.saveConsumedSnapshot(draft.mealId);


      await ref.read(updateMealByIdProvider(draft.mealId, 'summarized').future);
    });
  }
}