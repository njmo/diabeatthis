import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/persistence/insert_ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/add_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_ingredient_amounts_repository.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/persistence/resolve_portion_selection.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late AddMealIngredientStageNotifier flow;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container.listen(addMealIngredientStageProvider, (_, _) {});
    flow = container.read(addMealIngredientStageProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<IngredientDraft> savedIngredient({
    String name = 'Apple',
    bool isReference = false,
  }) async {
    final ingredient = await insertIngredientDraft(
      db,
      regressionIngredient(name: name, isReference: isReference),
    );
    return ingredient.toDraft();
  }

  Future<PortionSelection> globalPortion(String name) async {
    final portion = await resolvePortionSelection(
      db,
      PortionSelection.draft(name: name, unitHint: 'g'),
    );
    return PortionSelection.existing(
      id: portion!.id,
      name: portion.name,
      unitHint: portion.unitHint,
    );
  }

  Future<void> selectIngredient(IngredientDraft ingredient) async {
    container.read(ingredientDraftProvider.notifier).overrideDraft(ingredient);
    await flow.nextStage();
  }

  MealIngredientsDraft complete({
    required double amount,
    ConfidenceLevel confidence = ConfidenceLevel.high,
  }) {
    container.read(mealIngredientAmountDraftProvider.notifier).setValue(amount);
    container
        .read(mealIngredientConfidenceDraftProvider.notifier)
        .setConfidence(confidence);
    return flow.completeAmountForm();
  }

  Future<MealIngredientsDraft> saveAndReload(MealIngredientsDraft draft) async {
    final saved = await container
        .read(addMealUseCaseProvider)
        .call(
          MealDraft(
            name: 'Ingredient flow regression',
            mealIngredients: [draft],
            plannedAt: DateTime.utc(2026, 11, 2, 12),
            status: 'planned',
          ),
        );
    final reloaded = await container.read(
      getMealIngredientsDraftForMealProvider(saved.id).future,
    );
    expect(reloaded, hasLength(1));
    return reloaded.single;
  }

  test(
    'assigned portion goes directly to quantity and reuses its stored weight after saving',
    () async {
      final ingredient = await savedIngredient();
      final portion = await globalPortion('sztuka');
      final ingredientId = ingredient.getIngredientIdOrNull()!;
      final portionId = portion.map(
        existing: (value) => value.id,
        draft: (_) => throw StateError('Expected an existing portion'),
        empty: (_) => throw StateError('Expected a portion'),
      );
      await db.insertIngredientPortion(ingredientId, portionId, 150);

      await selectIngredient(ingredient);
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.definedPortionsSearch,
      );
      expect(
        container.read(portionFilterProvider),
        PortionFilter.byQueryForIngredient(ingredientId: ingredientId),
      );
      container.read(portionDraftProvider.notifier).overrideDraft(portion);
      await flow.nextStage();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.amountForm,
      );
      final storedWeight = await container.read(
        gramsPerPortionProvider(ingredient, portion).future,
      );
      expect(storedWeight, 150);
      final result = complete(amount: 2.5);
      final reloaded = await saveAndReload(result);

      expect(reloaded.ingredient.getIngredientIdOrNull(), ingredientId);
      expect(reloaded.ingredientPortion.portion, portion);
      expect(reloaded.ingredientPortion.amount, 150);
      expect(reloaded.amount, 2.5);
      expect(reloaded.quantityConfidence, 0.75);
      expect(reloaded.ingredient.nutritionConfidence, 0.75);
      expect((await db.select(db.ingredientPortions).get()), hasLength(1));
      final entry = (await db.select(db.mealIngredients).get()).single;
      final amounts = await MealIngredientAmountsRepository(db).load(entry);
      expect(amounts.plannedGrams, 375);
    },
  );

  test(
    'assigning an unassigned global portion keeps its identity and creates only the ingredient weight',
    () async {
      final ingredient = await savedIngredient();
      final portion = await globalPortion('small piece');
      final ingredientId = ingredient.getIngredientIdOrNull()!;
      await selectIngredient(ingredient);
      flow.toOppositeStage();

      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionAddNewSearch,
      );
      expect(
        container.read(portionFilterProvider),
        PortionFilter.allUnassignedForIngredient(ingredientId: ingredientId),
      );
      final available = await container.read(
        portionsNotInIngredientByQueryProvider(ingredientId, 'small').future,
      );
      expect(available.map((value) => value.name), contains('small piece'));
      container.read(portionDraftProvider.notifier).overrideDraft(portion);
      await flow.nextStage();
      expect(
        container.read(addMealIngredientStageProvider),
        AddMealIngredientStage.portionSpecifyAmount,
      );
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(85);
      await flow.nextStage();
      final reloaded = await saveAndReload(complete(amount: 1.5));

      expect(reloaded.ingredientPortion.portion, portion);
      expect(reloaded.ingredientPortion.amount, 85);
      expect(
        (await db.select(db.portion).get()).where(
          (value) => value.name == 'small piece',
        ),
        hasLength(1),
      );
      final unavailable = await db.portionDao
          .getUnassignedPortionsForIngredientByQuery(ingredientId, 'small');
      expect(unavailable, isEmpty);
    },
  );

  test(
    'a new global portion preserves its name, weight unit and entered weight across back and save',
    () async {
      final ingredient = await savedIngredient();
      await selectIngredient(ingredient);
      flow.toOppositeStage();
      flow.toOppositeStage();
      container
          .read(portionDraftProvider.notifier)
          .overrideDraft(
            const PortionSelection.draft(name: 'thin slice', unitHint: 'g'),
          );
      await flow.nextStage();
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(22.5);
      await flow.nextStage();
      container.read(mealIngredientAmountDraftProvider.notifier).setValue(3.5);
      flow.back();

      expect(
        container.read(mealIngredientsDraftProvider).ingredientPortion.amount,
        22.5,
      );
      await flow.nextStage();
      expect(container.read(mealIngredientAmountDraftProvider), 3.5);
      final reloaded = await saveAndReload(complete(amount: 3.5));
      expect(reloaded.ingredientPortion.amount, 22.5);
      reloaded.ingredientPortion.portion.map(
        existing: (value) {
          expect(value.name, 'thin slice');
          expect(value.unitHint, 'g');
        },
        draft: (_) => fail('The portion must be saved'),
        empty: (_) => fail('The portion must be retained'),
      );
    },
  );

  test(
    'switching from a portion to grams clears the old multiplier and keeps fractional grams',
    () async {
      final ingredient = await savedIngredient();
      final portion = await globalPortion('slice');
      await selectIngredient(ingredient);
      container.read(portionDraftProvider.notifier).overrideDraft(portion);
      await flow.nextStage();
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(40);
      container.read(mealIngredientAmountDraftProvider.notifier).setValue(2);
      flow.back();
      flow.setOverride();

      expect(container.read(mealIngredientAmountDraftProvider), 0);
      final result = complete(
        amount: 125.5,
        confidence: ConfidenceLevel.certain,
      );
      final reloaded = await saveAndReload(result);
      expect(
        reloaded.ingredientPortion.portion,
        const PortionSelection.empty(),
      );
      expect(reloaded.amount, 125.5);
      expect(reloaded.quantityConfidence, 0.95);
      final entry = (await db.select(db.mealIngredients).get()).single;
      expect(entry.portionId, isNull);
      final amounts = await MealIngredientAmountsRepository(db).load(entry);
      expect(amounts.plannedGrams, 125.5);
      expect(await db.select(db.ingredientPortions).get(), isEmpty);
    },
  );

  for (final isNew in [false, true]) {
    test(
      'reference ingredient skips portion definitions and persists fractional reference quantities (new: $isNew)',
      () async {
        final reference = isNew
            ? regressionIngredient(name: 'Reference dinner', isReference: true)
            : await savedIngredient(
                name: 'Reference dinner',
                isReference: true,
              );
        if (isNew) {
          flow.startManualIngredient();
        }
        await selectIngredient(reference);
        expect(
          container.read(addMealIngredientStageProvider),
          AddMealIngredientStage.amountForm,
        );
        final result = complete(amount: 1.5, confidence: ConfidenceLevel.low);
        expect(
          result.ingredientPortion.portion,
          const PortionSelection.empty(),
        );
        final reloaded = await saveAndReload(result);

        expect(reloaded.ingredient.isReference, isTrue);
        expect(reloaded.ingredient.carbsPer100g, 40);
        expect(reloaded.ingredient.fatPer100g, 10);
        expect(reloaded.ingredient.proteinPer100g, 25);
        expect(reloaded.ingredient.nutritionConfidence, 0.75);
        expect(reloaded.quantityConfidence, 0.25);
        expect(reloaded.amount, 1.5);
        expect(await db.select(db.ingredientPortions).get(), isEmpty);
        final entry = (await db.select(db.mealIngredients).get()).single;
        expect(entry.portionId, isNull);
        final amounts = await MealIngredientAmountsRepository(db).load(entry);
        expect(amounts.plannedGrams, 150);
      },
    );
  }

  test(
    'editing a saved item retains its database identity and consumption facts after changing measure',
    () async {
      final ingredient = await savedIngredient();
      await selectIngredient(ingredient);
      flow.setOverride();
      final saved = await saveAndReload(complete(amount: 120));
      final original = saved.copyWith(
        entryType: 'extra',
        consumedAmount: 95,
        consumedConfidence: 0.91,
        quantityConfidence: 0.82,
      );
      flow.editIngredient(original);
      flow.back();
      flow.toOppositeStage();
      final portion = await globalPortion('spoon');
      container.read(portionDraftProvider.notifier).overrideDraft(portion);
      await flow.nextStage();
      container
          .read(mealIngredientsDraftProvider.notifier)
          .setIngredientPortionAmount(12);
      await flow.nextStage();
      final result = complete(amount: 2.5);

      expect(result.mealIngredientId, original.mealIngredientId);
      expect(result.ingredient, original.ingredient);
      expect(result.entryType, 'extra');
      expect(result.consumedAmount, 95);
      expect(result.consumedConfidence, 0.91);
      expect(result.quantityConfidence, 0.82);
      expect(result.amount, 2.5);
      expect(result.ingredientPortion.amount, 12);
      expect(container.read(mealDraftProvider).mealIngredients, isEmpty);
    },
  );
}

IngredientDraft regressionIngredient({
  required String name,
  bool isReference = false,
}) {
  return IngredientDraft.draft(
    name: name,
    carbsPer100g: isReference ? 40 : 12,
    fatPer100g: isReference ? 10 : 0.2,
    fiberPer100g: isReference ? 0 : 2,
    proteinPer100g: isReference ? 25 : 0.3,
    nutritionConfidence: 0.75,
    isReference: isReference,
    carbsLabelMode: CarbsLabelMode.eu,
    iconAssetPath: 'assets/icons/food/prepared_meal.png',
  );
}
