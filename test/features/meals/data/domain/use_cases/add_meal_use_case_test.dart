import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('rejects meals without ingredients', () async {
    final useCase = container.read(addMealUseCaseProvider);

    await expectLater(
      useCase.call(
        MealDraft(
          name: 'Test',
          mealIngredients: const [],
          plannedAt: clock.now(),
          status: 'confirmed',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('rejects meal ingredients without energy macros', () async {
    final useCase = container.read(addMealUseCaseProvider);

    await expectLater(
      useCase.call(
        MealDraft(
          name: 'Test',
          mealIngredients: [
            MealIngredientsDraft(
              ingredient: IngredientDraft.draft(
                name: 'Pusty składnik',
                carbsPer100g: 0,
                fatPer100g: 0,
                fiberPer100g: 0,
                proteinPer100g: 0,
                nutritionConfidence: 0.25,
                isReference: false,
              ),
              ingredientPortion: const IngredientPortionDraft(
                portion: PortionSelection.empty(),
                amount: 0,
              ),
              amount: 1,
              quantityConfidence: 1,
              entryType: 'planned',
              consumedAmount: null,
              consumedConfidence: null,
            ),
          ],
          plannedAt: clock.now(),
          status: 'confirmed',
        ),
      ),
      throwsArgumentError,
    );
  });
}
