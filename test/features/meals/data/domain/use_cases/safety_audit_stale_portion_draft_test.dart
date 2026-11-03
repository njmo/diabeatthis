import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_service.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/resolve_meal_ingredient_grams_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/regression/safety_audit_unused_llm_client.dart';

void main() {
  for (final changePortion in [false, true]) {
    test(
      'saving a meal preserves reviewed grams or explicitly rejects a changed portion: changed=$changePortion',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            ingredientIconServiceProvider.overrideWithValue(
              IngredientIconService(client: SafetyAuditUnusedLlmClient()),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final ingredientId = await db
            .into(db.ingredient)
            .insert(
              IngredientCompanion.insert(
                name: 'Bread',
                carbsPer100g: 50,
                fiberPer100g: 0,
                fatPer100g: 0,
                proteinPer100g: 0,
                nutritionConfidence: 1,
                carbsLabelMode: const Value('eu'),
                iconAssetPath: const Value('assets/bread.svg'),
              ),
            );
        final portionId = await db
            .into(db.portion)
            .insert(PortionCompanion.insert(name: 'Slice', unitHint: 'piece'));
        await db.insertIngredientPortion(ingredientId, portionId, 30);
        final item = MealIngredientsDraft(
          ingredient: IngredientDraft.existing(
            id: ingredientId,
            name: 'Bread',
            carbsPer100g: 50,
            fiberPer100g: 0,
            fatPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            isReference: false,
            iconAssetPath: 'assets/bread.svg',
          ),
          ingredientPortion: IngredientPortionDraft(
            portion: PortionSelection.existing(
              id: portionId,
              name: 'Slice',
              unitHint: 'piece',
            ),
            amount: 30,
          ),
          amount: 2,
          quantityConfidence: 1,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
        );
        final resolver = Provider(
          (ref) => ResolveMealIngredientGramsUseCase(ref),
        );
        final reviewedGrams = await container.read(resolver).call(item);
        expect(reviewedGrams, 60);
        if (changePortion) {
          await db.portionDao.updateIngredientPortionAmount(
            ingredientId: ingredientId,
            portionId: portionId,
            gramsPerPortion: 40,
          );
        }
        expect(await container.read(resolver).call(item), reviewedGrams);
        int? savedMealId;
        try {
          final saved = await container.read(addMealUseCaseProvider)(
            MealDraft(
              name: 'Two reviewed slices',
              mealIngredients: [item],
              plannedAt: DateTime(2026, 9, 1, 12),
              status: 'planned',
            ),
          );
          savedMealId = saved.id;
        } on StateError {
          if (!changePortion) {
            rethrow;
          }
          // Explicit stale-draft rejection is also safe; no partial meal may remain.
          expect(await db.select(db.meal).get(), isEmpty);
          return;
        } on ArgumentError {
          if (!changePortion) {
            rethrow;
          }
          expect(await db.select(db.meal).get(), isEmpty);
          return;
        }
        final savedNutrition = await db.ingredientDao.totalsForMeal(
          savedMealId,
        );
        expect(savedNutrition!.totalGrams, reviewedGrams);
        expect(savedNutrition.netCarbsGrams, 30);
      },
    );
  }
}
