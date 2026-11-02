import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';

void main() {
  final start = DateTime(2026, 11, 1, 12);
  final end = start.add(const Duration(minutes: 15));
  for (final scenario in [
    (planned: 100.0, consumed: 50.0, expected: 0),
    (planned: 200.0, consumed: 100.0, expected: 11),
  ]) {
    test(
      'completion returns ${scenario.expected} eCarbs from persisted half portions rather than cached macros',
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
        try {
          await db.customInsert('''INSERT INTO ingredient
          (id, name, carbs_per_100g, fat_per_100g, fiber_per_100g, protein_per_100g, nutrition_confidence)
          VALUES (1, 'Meal ingredient', 20, 10, 0, 5, 1)''');
          await db.customInsert(
            "INSERT INTO meal (id, name, planned_at, status) VALUES (1, 'Meal', 1000, 'planned')",
          );
          await db.customInsert('''INSERT INTO meal_ingredients
          (id, meal_id, ingredient_id, amount, quantity_confidence)
          VALUES (1, 1, 1, ${scenario.planned}, 1)''');
          await db.customInsert('''INSERT INTO meal_advisor_result
          (meal_id, result, initial_wait_time, final_wait_time, wait_time_ignored, extended_carbs_grams)
          VALUES (1, 'eating-then-bolus', 0, 0, 0, 22)''');
          await db.mealDao.updateMealStatus(
            1,
            'eating-then-bolus',
            occurredAt: start,
          );
          await container.read(
            mealMacronutrientsConsumedSummaryProvider(1).future,
          );
          final result = await withClock(
            Clock.fixed(end),
            () => container
                .read(completeMealUseCaseProvider)
                .call(
                  draft: MealSummaryDraft(
                    mealId: 1,
                    mealStatus: 'eating-then-bolus',
                    itemIds: const [1],
                    extraItems: const [],
                    itemsById: {
                      1: MealSummaryItemDraft(
                        name: 'Meal ingredient',
                        mealIngredientId: 1,
                        plannedAmount: scenario.planned,
                        reportedAmount: scenario.planned,
                        amountLabel: 'g',
                        netCarbsPerAmount: 0.2,
                        gramsPerAmount: 1,
                        consumedAmount: scenario.consumed,
                        consumedConfidence: 1,
                      ),
                    },
                  ),
                  choice: MealCompletionChoice.less,
                  endedAt: end,
                ),
          );
          expect(result.requiresBolus, isTrue);
          expect(result.consumedCarbs, (scenario.consumed * 0.2).ceil());
          expect(result.consumedExtendedCarbs, scenario.expected);
          expect(result.aapsCarbs!.extendedCarbs, scenario.expected);
          expect(
            (await db.mealDao.getMealById(1))?.status,
            'waiting-for-bolus',
          );
          final savedAdvice = await db.mealAdvisorResultDao
              .getMealAdvisorResult(1);
          expect(savedAdvice?.extendedCarbsGrams, 22);
        } finally {
          container.dispose();
          await db.close();
        }
      },
    );
  }
}
