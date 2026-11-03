import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/fake_notifications_controller.dart';
import '../../helpers/regression/historical_nutrition_scenario.dart';

void main() {
  for (final previousConsumedSnapshot in [false, true]) {
    test(
      'saving explicit zero consumption exposes zero historical macros; previous consumed snapshot=$previousConsumedSnapshot',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notificationsControllerUiProvider.overrideWithValue(
              FakeNotificationsController(),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final scenario = HistoricalNutritionScenario(db);
        await scenario.seedIngredient();
        final mealId = await scenario.seedMeal(
          consumed: previousConsumedSnapshot,
        );
        await db.mealDao.updateMealStatus(mealId, 'eaten');
        final row = (await db.mealIngredientsDao.getMealIngredientsForMeal(
          mealId,
        )).single;
        await container.read(finalizeMealSummaryUseCaseProvider)(
          MealSummaryDraft(
            mealId: mealId,
            mealStatus: 'eaten',
            itemIds: [row.id],
            itemsById: {
              row.id: MealSummaryItemDraft(
                name: 'Recorded ingredient',
                mealIngredientId: row.id,
                plannedAmount: 200,
                reportedAmount: 150,
                amountLabel: 'g',
                netCarbsPerAmount: .15,
                gramsPerAmount: 1,
                consumedAmount: 0,
                consumedConfidence: 1,
              ),
            },
            extraItems: [],
          ),
        );
        final saved = (await db.mealIngredientsDao.getMealIngredientsForMeal(
          mealId,
        )).single;
        expect(saved.consumedAmount, 0);
        expect((await db.mealDao.getMealById(mealId))!.status, 'summarized');
        final details = await container.read(loadMealDetailsUseCaseProvider)(
          mealId,
        );
        final facts = const MealAiFactsMapper().map(details);
        expect(facts.ingredients, isEmpty);
        expect(facts.macros!.netCarbsGrams, 0);
        expect(facts.macros!.totalGrams, 0);
        expect(facts.macroSource, 'consumed');
      },
    );
  }
}
