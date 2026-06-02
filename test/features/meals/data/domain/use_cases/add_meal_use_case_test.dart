import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
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

  test('rejects meals without net carbs or WBT e-carbs', () async {
    final useCase = container.read(addMealUseCaseProvider);

    await expectLater(
      useCase.call(
        MealDraft(
          name: 'Test',
          mealIngredients: [
            _mealIngredient(
              ingredient: IngredientDraft.draft(
                name: 'Low fat no carbs',
                carbsPer100g: 0,
                fatPer100g: 1,
                fiberPer100g: 0,
                proteinPer100g: 0,
                nutritionConfidence: 0.95,
                isReference: false,
              ),
              gramsPerPortion: 50,
            ),
          ],
          plannedAt: clock.now(),
          status: 'confirmed',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('allows EU label ingredients with fiber greater than carbs', () async {
    final useCase = container.read(addMealUseCaseProvider);

    final meal = await useCase.call(
      MealDraft(
        name: 'Test',
        mealIngredients: [
          _mealIngredient(
            ingredient: IngredientDraft.draft(
              name: 'Oli',
              carbsPer100g: 1,
              fatPer100g: 3,
              fiberPer100g: 5,
              proteinPer100g: 2,
              nutritionConfidence: 0.95,
              isReference: false,
              carbsLabelMode: CarbsLabelMode.eu,
            ),
            gramsPerPortion: 50,
          ),
        ],
        plannedAt: clock.now(),
        status: 'confirmed',
      ),
    );

    expect(meal.name, 'Test');
  });

  test('rounds positive EU net carbs up before meal validation', () async {
    final useCase = container.read(addMealUseCaseProvider);

    final meal = await useCase.call(
      MealDraft(
        name: 'Test',
        mealIngredients: [
          _mealIngredient(
            ingredient: IngredientDraft.draft(
              name: 'Small EU portion',
              carbsPer100g: 6,
              fatPer100g: 0,
              fiberPer100g: 7,
              proteinPer100g: 0,
              nutritionConfidence: 0.75,
              isReference: false,
              carbsLabelMode: CarbsLabelMode.eu,
            ),
            gramsPerPortion: 5,
          ),
        ],
        plannedAt: clock.now(),
        status: 'confirmed',
      ),
    );

    expect(meal.name, 'Test');
  });

  test('rejects non-UE meals without net carbs or WBT e-carbs', () async {
    final useCase = container.read(addMealUseCaseProvider);

    await expectLater(
      useCase.call(
        MealDraft(
          name: 'Test',
          mealIngredients: [
            _mealIngredient(
              ingredient: IngredientDraft.draft(
                name: 'Oli',
                carbsPer100g: 1,
                fatPer100g: 3,
                fiberPer100g: 5,
                proteinPer100g: 2,
                nutritionConfidence: 0.95,
                isReference: false,
                carbsLabelMode: CarbsLabelMode.nonEu,
              ),
              gramsPerPortion: 50,
            ),
          ],
          plannedAt: clock.now(),
          status: 'confirmed',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('allows meals with WBT e-carbs even when net carbs are zero', () async {
    final useCase = container.read(addMealUseCaseProvider);

    final meal = await useCase.call(
      MealDraft(
        name: 'Test',
        mealIngredients: [
          _mealIngredient(
            ingredient: IngredientDraft.draft(
              name: 'Tlusty skladnik',
              carbsPer100g: 0,
              fatPer100g: 30,
              fiberPer100g: 0,
              proteinPer100g: 10,
              nutritionConfidence: 0.75,
              isReference: false,
              carbsLabelMode: CarbsLabelMode.eu,
            ),
            gramsPerPortion: 100,
          ),
        ],
        plannedAt: clock.now(),
        status: 'confirmed',
      ),
    );

    expect(meal.name, 'Test');
  });
}

MealIngredientsDraft _mealIngredient({
  required IngredientDraft ingredient,
  required double gramsPerPortion,
}) {
  return MealIngredientsDraft(
    ingredient: ingredient,
    ingredientPortion: IngredientPortionDraft(
      portion: const PortionSelection.draft(name: 'sztuka', unitHint: 'g'),
      amount: gramsPerPortion,
    ),
    amount: 1,
    quantityConfidence: 1,
    entryType: 'planned',
    consumedAmount: null,
    consumedConfidence: null,
  );
}
