import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/load_meal_summary_data_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/copy_recorded_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/data/mappers/similar_meal_query_mapper.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/recorded_portion_meal_fixture.dart';

void main() {
  for (final deletedPortion in [false, true]) {
    test(
      'historical similarity, copy and summary retain original mass; deleted=$deletedPortion',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final at = await seedRecordedPortionMeal(db);
        await db.portionDao.updateIngredientPortionAmount(
          ingredientId: 1,
          portionId: 999,
          gramsPerPortion: 40,
        );
        if (deletedPortion) {
          await db.customStatement('DELETE FROM portion WHERE id = 999');
        }
        final history = await MealContextLocalHistoryRepository(db)
            .loadSimilarMeals(
              at.subtract(const Duration(days: 1)),
              DateTime.now().add(const Duration(days: 1)),
              null,
            );
        expect(history.single.composition!.grams, {1: 70});
        final draft = await container.read(
          getMealIngredientsDraftForMealProvider(1).future,
        );
        final copied = copyRecordedMealIngredient(draft.first);
        expect(copied.amount, 60);
        expect(copied.consumedAmount, 60);
        expect(copied.mealIngredientId, isNull);
        expect(copied.recordedGramsPerAmount, isNull);
        final summary = await container
            .read(loadMealSummaryDataUseCaseProvider)
            .call(1);
        expect(summary.items.first.plannedAmount, 2);
        expect(summary.items.first.gramsPerAmount, 30);
        expect(summary.items.first.netCarbsPerAmount, 15);
        await container
            .read(mealSnapshotControllerProvider)
            .saveConsumedSnapshot(1);
        final savedSnapshot = (await db.select(db.mealSnapshot).get()).single;
        expect(savedSnapshot.totalGrams, 70);
        expect(savedSnapshot.carbWeightedNutritionConfidence, 1);
        expect(savedSnapshot.carbWeightedQuantityConfidence, 1);
        if (deletedPortion) {
          final subscription = container.listen(
            mealIngredientsDraftProvider,
            (_, _) {},
          );
          final editor = container.read(mealIngredientsDraftProvider.notifier);
          editor.overrideMealIngredient(draft.first);
          expect(
            container.read(mealIngredientsDraftProvider).recordedGramsPerAmount,
            30,
          );
          editor.setIngredientPortion(const PortionSelection.empty());
          expect(
            container.read(mealIngredientsDraftProvider).recordedGramsPerAmount,
            isNull,
          );
          editor.overrideMealIngredient(draft.first);
          editor.setIngredientPortionAmount(40);
          expect(
            container.read(mealIngredientsDraftProvider).recordedGramsPerAmount,
            isNull,
          );
          editor.overrideMealIngredient(draft.first);
          editor.setIngredient(draft.first.ingredient);
          expect(
            container.read(mealIngredientsDraftProvider).recordedGramsPerAmount,
            isNull,
          );
          subscription.close();
        }
        await db.mealIngredientsDao.updateMealIngredientConsumed(
          draft.first.mealIngredientId!,
          3,
          1,
        );
        expect(
          (await db.ingredientDao.totalsForMealConsumed(1))!.totalGrams,
          100,
        );
      },
    );
  }

  test(
    'mixed legacy unknown conversion preserves aggregate and disables complete similarity composition',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final at = await seedRecordedPortionMeal(db);
      await db.withRecordedPortionConversionsPreserved(() async {
        await db.customStatement(
          'UPDATE meal_ingredients SET grams_per_portion_used = NULL WHERE portion_id = 999',
        );
      });
      final history = await MealContextLocalHistoryRepository(db)
          .loadSimilarMeals(
            at.subtract(const Duration(days: 1)),
            DateTime.now().add(const Duration(days: 1)),
            null,
          );
      expect(history.single.composition, isNull);
      final details = await container
          .read(loadMealDetailsUseCaseProvider)
          .call(1);
      final query = const SimilarMealQueryMapper().map(details)!;
      expect(query.composition, isNull);
      expect(query.target.totalGrams, 70);
      expect(query.target.netCarbsGrams, 35);
      await expectLater(
        container.read(getMealIngredientsDraftForMealProvider(1).future),
        throwsStateError,
      );
    },
  );
}
