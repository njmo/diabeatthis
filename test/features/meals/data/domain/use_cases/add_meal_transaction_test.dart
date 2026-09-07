import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
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
      retry: (_, _) => null,
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> failSecondIngredient() => db.customStatement('''
    CREATE TRIGGER fail_second_meal_ingredient
    BEFORE INSERT ON meal_ingredients
    WHEN NEW.amount = 2
    BEGIN
      SELECT RAISE(ABORT, 'Injected ingredient write failure');
    END;
  ''');

  Future<Map<String, List<Map<String, Object?>>>> snapshot() async {
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in [
      'meal',
      'ingredient',
      'portion',
      'ingredient_portions',
      'meal_ingredients',
    ]) {
      result[table] = (await db.customSelect('SELECT * FROM $table').get())
          .map((row) => row.data)
          .toList();
    }
    return result;
  }

  test('rolls back all meal writes when the second ingredient fails', () async {
    await db.customStatement(
      "INSERT INTO portion (name, unit_hint) VALUES ('Existing portion', 'g')",
    );
    final before = await snapshot();
    await failSecondIngredient();
    final useCase = container.read(addMealUseCaseProvider);

    await expectLater(
      useCase.call(transactionMealDraft()),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.message,
          'message',
          contains('Injected ingredient write failure'),
        ),
      ),
    );

    expect(await snapshot(), before);
  });

  test('retries the same draft after a rolled back write', () async {
    await failSecondIngredient();
    final useCase = container.read(addMealUseCaseProvider);
    final draft = transactionMealDraft();
    await expectLater(useCase.call(draft), throwsA(isA<SqliteException>()));
    await db.customStatement('DROP TRIGGER fail_second_meal_ingredient');

    final meal = await useCase.call(draft);

    final saved = await snapshot();
    expect(saved['meal'], hasLength(1));
    expect(saved['meal']!.single['id'], meal.id);
    expect(saved['ingredient'], hasLength(2));
    expect(saved['portion'], hasLength(2));
    expect(saved['ingredient_portions'], hasLength(2));
    expect(saved['meal_ingredients'], hasLength(2));
    expect(
      saved['meal_ingredients']!.map((row) => row['meal_id']),
      everyElement(meal.id),
    );
    expect(
      saved['meal_ingredients']!.map((row) => row['amount']),
      unorderedEquals([1.0, 2.0]),
    );
  });

  test(
    'rejects duplicate meal name and time instead of returning cached success',
    () async {
      final useCase = container.read(addMealUseCaseProvider);
      final draft = transactionMealDraft();
      await useCase.call(draft);
      final before = await snapshot();

      await expectLater(
        useCase.call(draft),
        throwsA(
          isA<SqliteException>().having(
            (error) => error.message,
            'message',
            contains('meal.name, meal.planned_at'),
          ),
        ),
      );

      expect(await snapshot(), before);
    },
  );

  test(
    'saves a copied meal at another time using existing ingredients and portions',
    () async {
      final useCase = container.read(addMealUseCaseProvider);
      final draft = transactionMealDraft();
      final first = await useCase.call(draft);
      final copiedIngredients = await container.read(
        getMealIngredientsDraftForMealProvider(first.id).future,
      );

      final second = await useCase.call(
        draft.copyWith(
          plannedAt: draft.plannedAt.add(const Duration(days: 1)),
          mealIngredients: copiedIngredients,
        ),
      );

      expect(second.id, isNot(first.id));
      final saved = await snapshot();
      expect(saved['meal'], hasLength(2));
      expect(saved['ingredient'], hasLength(2));
      expect(saved['portion'], hasLength(2));
      expect(saved['ingredient_portions'], hasLength(2));
      expect(
        saved['meal_ingredients']!.where((row) => row['meal_id'] == first.id),
        hasLength(2),
      );
      expect(
        saved['meal_ingredients']!.where((row) => row['meal_id'] == second.id),
        hasLength(2),
      );
    },
  );

  test('reuses a new portion shared by different ingredients', () async {
    final draft = transactionMealDraft();
    final sharedPortion = draft.mealIngredients.first.ingredientPortion;
    await container
        .read(addMealUseCaseProvider)
        .call(
          draft.copyWith(
            mealIngredients: draft.mealIngredients
                .map((item) => item.copyWith(ingredientPortion: sharedPortion))
                .toList(),
          ),
        );

    final saved = await snapshot();
    expect(saved['portion'], hasLength(1));
    expect(saved['ingredient_portions'], hasLength(2));
    expect(
      saved['meal_ingredients']!.map((row) => row['portion_id']),
      everyElement(saved['portion']!.single['id']),
    );
  });

  test(
    'preserves gram amounts and reference ingredient normalization',
    () async {
      final draft = transactionMealDraft(usePortions: false);
      final regular = draft.mealIngredients.first.copyWith(amount: 75);
      final reference = draft.mealIngredients.last;
      await container
          .read(addMealUseCaseProvider)
          .call(
            draft.copyWith(
              mealIngredients: [
                regular,
                reference.copyWith(
                  ingredient: reference.ingredient.copyWith(
                    isReference: true,
                    fiberPer100g: 3,
                  ),
                  amount: 0.5,
                ),
              ],
            ),
          );

      final saved = await snapshot();
      expect(saved['portion'], isEmpty);
      expect(saved['ingredient_portions'], isEmpty);
      expect(
        saved['meal_ingredients']!.map((row) => row['amount']),
        unorderedEquals([75.0, 0.5]),
      );
      expect(
        saved['meal_ingredients']!.map((row) => row['quantity_confidence']),
        everyElement(0.75),
      );
      expect(
        saved['ingredient']!.singleWhere(
          (row) => row['is_reference'] == 1,
        )['fiber_per_100g'],
        0,
      );
    },
  );
}

MealDraft transactionMealDraft({bool usePortions = true}) {
  return MealDraft(
    name: 'Transaction test meal',
    plannedAt: DateTime(2026, 9, 7, 12),
    status: 'planned',
    mealIngredients: [
      for (final index in [1, 2])
        MealIngredientsDraft(
          ingredient: IngredientDraft.draft(
            name: 'Ingredient $index',
            carbsPer100g: 20,
            fatPer100g: 5,
            fiberPer100g: 0,
            proteinPer100g: 4,
            nutritionConfidence: 0.75,
            isReference: false,
          ),
          ingredientPortion: IngredientPortionDraft(
            portion: usePortions
                ? PortionSelection.draft(name: 'Portion $index', unitHint: 'g')
                : const PortionSelection.empty(),
            amount: usePortions ? 50 : 0,
          ),
          amount: index.toDouble(),
          quantityConfidence: 0.75,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
        ),
    ],
  );
}
