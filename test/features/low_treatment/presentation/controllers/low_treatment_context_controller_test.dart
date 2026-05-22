import 'package:diabeatthis/core/domain/model/ingredient.dart' as domain;
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/domain/model/portion.dart' as domain;
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart'
    as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/device_status_factory.dart';

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

  test('creates low treatment meal and context from dashboard draft', () async {
    final relatedMeal = await db
        .into(db.meal)
        .insertReturning(MealCompanion.insert(name: 'Obiad', plannedAt: 1000));
    final deviceStatusDate = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    container
        .read(deviceStatusValueProvider.notifier)
        .update(
          testDeviceStatus(
            date: deviceStatusDate,
            iob: 0.4,
            cob: 2,
            tick: '-1',
            bg: 74,
            carbsReq: 8,
            carbsReqWithin: 10,
          ),
        );

    final mealDraft = MealDraft(
      name: 'Dosłodzenie',
      mealIngredients: const [],
      plannedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      status: 'draft',
    );
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );

    final draft = controller.composeDashboardDraft(
      meal: mealDraft,
      relatedMealId: relatedMeal.id,
    );
    final context = await controller.save(draft);
    final lowTreatment = await db.mealDao.getMealById(context.mealId);

    expect(lowTreatment?.purpose, 'lowTreatment');
    expect(lowTreatment?.status, 'confirmed');
    expect(context.relatedMealId, relatedMeal.id);
    expect(context.source, LowTreatmentContextSource.dashboardAction);
    expect(context.suggestedCarbs, 8);
    expect(context.suggestedWithinMinutes, 10);
    expect(context.deviceStatusDate, deviceStatusDate);
    expect(context.reason, LowTreatmentReason.carbsReq);
  });

  test('updates low treatment draft ingredients', () {
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    final first = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);
    final second = _ingredientDraft(name: 'Sok', carbsPer100g: 11);

    controller.addMealIngredient(first);
    expect(
      container.read(lowTreatmentContextControllerProvider).mealIngredients,
      [first],
    );

    controller.updateMealIngredient(first, second);
    expect(
      container.read(lowTreatmentContextControllerProvider).mealIngredients,
      [second],
    );

    controller.removeMealIngredient(second);
    expect(
      container.read(lowTreatmentContextControllerProvider).mealIngredients,
      isEmpty,
    );
  });

  test('sets low treatment draft ingredient from quick item', () {
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    const quickItem = domain.QuickLowTreatmentItem(
      id: 1,
      name: 'Dextro',
      ingredient: domain.Ingredient(
        id: 12,
        name: 'Dextro',
        carbsPer100g: 90,
        fatPer100g: 0,
        fiberPer100g: 0,
        proteinPer100g: 0,
        nutritionConfidence: 1,
        isReference: false,
      ),
      portion: domain.Portion(id: 4, name: 'cukierek', unitHint: 'szt.'),
      amount: 2,
      sortOrder: 1,
      isActive: true,
      gramsPerPortion: 3,
    );

    controller.setQuickLowTreatmentItem(quickItem);

    final ingredients = container.read(
      lowTreatmentContextControllerProvider.select(
        (state) => state.mealIngredients,
      ),
    );

    expect(ingredients, hasLength(1));
    expect(ingredients.single.ingredient.name, 'Dextro');
    expect(ingredients.single.amount, 2);
    expect(ingredients.single.ingredientPortion.amount, 3);
  });

  test('saves current low treatment draft with ingredients', () async {
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    controller.addMealIngredient(ingredient);
    final context = await controller.saveCurrentDraft();

    final lowTreatment = await db.mealDao.getMealById(context.mealId);
    final mealIngredients = await db.mealIngredientsDao
        .getMealIngredientsForMeal(context.mealId);

    expect(lowTreatment?.name, 'Dosłodzenie');
    expect(lowTreatment?.purpose, 'lowTreatment');
    expect(lowTreatment?.status, 'confirmed');
    expect(context.source, LowTreatmentContextSource.dashboardAction);
    expect(context.reason, LowTreatmentReason.lowGlucose);
    expect(mealIngredients, hasLength(1));
  });

  test('keeps use case providers alive while saving context', () async {
    final subscription = container.listen(
      lowTreatmentContextControllerProvider,
      (_, _) {},
    );
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    await container.pump();
    controller.addMealIngredient(ingredient);
    final context = await controller.saveCurrentDraft();

    final storedContext = await db.lowTreatmentContextDao.getContextForMeal(
      context.mealId,
    );

    expect(storedContext, isNotNull);
    subscription.close();
  });

  test('blocks saving current low treatment draft while saving', () async {
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    controller.addMealIngredient(ingredient);
    final firstSave = controller.saveCurrentDraft();
    expect(controller.saveCurrentDraft, throwsA(isA<StateError>()));
    final context = await firstSave;

    final meals = await db.select(db.meal).get();

    expect(context.mealId, isPositive);
    expect(meals.where((meal) => meal.purpose == 'lowTreatment'), hasLength(1));
  });
}

MealIngredientsDraft _ingredientDraft({
  required String name,
  required double carbsPer100g,
}) {
  return MealIngredientsDraft(
    ingredient: IngredientDraft.draft(
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 1,
      isReference: false,
    ),
    ingredientPortion: IngredientPortionDraft(
      portion: PortionSelection.empty(),
      amount: 1,
    ),
    amount: 10,
    quantityConfidence: 1,
    entryType: 'planned',
    consumedAmount: null,
    consumedConfidence: null,
  );
}
