import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/recorded_portion_meal_fixture.dart';
import '../../../../helpers/regression/safety_audit_unused_llm_client.dart';

void main() {
  for (final changedAfterReview in [false, true]) {
    test('assigned portion captures the displayed weight at review; later change=$changedAfterReview', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        ingredientIconServiceProvider.overrideWithValue(IngredientIconService(client: SafetyAuditUnusedLlmClient())),
      ]);
      addTearDown(() async { container.dispose(); await db.close(); });
      await seedRecordedPortionMeal(db);
      await db.customStatement("UPDATE ingredient SET icon_asset_path = 'assets/bread.svg' WHERE id = 1");
      final original = (await container.read(getMealIngredientsDraftForMealProvider(1).future)).first;
      final selected = original.copyWith(mealIngredientId: null, ingredientPortion: original.ingredientPortion.copyWith(amount: 0));
      final draftSubscription = container.listen(mealIngredientsDraftProvider, (_, _) {});
      final stageSubscription = container.listen(addMealIngredientStageProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      addTearDown(stageSubscription.close);
      container.read(mealIngredientsDraftProvider.notifier).overrideMealIngredient(selected);
      container.read(mealIngredientAmountDraftProvider.notifier).setValue(2);
      final weightProvider = gramsPerPortionProvider(selected.ingredient, selected.ingredientPortion.portion);
      final weightSubscription = container.listen(weightProvider, (_, _) {});
      addTearDown(weightSubscription.close);
      expect(await container.read(weightProvider.future), 30);
      final controller = container.read(addMealIngredientStageProvider.notifier);
      controller.setStage(AddMealIngredientStage.amountForm);
      final reviewed = controller.completeAmountForm();
      expect(reviewed.ingredientPortion.amount, 30);
      expect(reviewed.amount, 2);
      if (changedAfterReview) {
        await db.portionDao.updateIngredientPortionAmount(ingredientId: 1, portionId: 999, gramsPerPortion: 40);
      }
      final operation = container.read(addMealUseCaseProvider).call(MealDraft(name: 'New reviewed meal', mealIngredients: [reviewed], plannedAt: DateTime.now(), status: 'planned'));
      if (changedAfterReview) {
        await expectLater(operation, throwsStateError);
        expect(await db.select(db.meal).get(), hasLength(1));
      } else {
        final saved = await operation;
        expect((await db.ingredientDao.totalsForMeal(saved.id))!.totalGrams, 60);
      }
    });
  }
}
