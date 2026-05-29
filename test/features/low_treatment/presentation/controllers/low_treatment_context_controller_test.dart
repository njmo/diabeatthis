import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart' as domain;
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/domain/model/portion.dart' as domain;
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart'
    as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/data/models/low_treatment_sheet_state.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart' as drift;
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
        .read(deviceStatusUiProvider.notifier)
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
      mealIngredients: [_ingredientDraft(name: 'Glukoza', carbsPer100g: 100)],
      plannedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      status: 'confirmed',
    );
    final controller = await _readyController(container);

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

  test('updates low treatment draft ingredients', () async {
    final controller = await _readyController(container);
    final first = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);
    final second = _ingredientDraft(name: 'Sok', carbsPer100g: 11);

    controller.addMealIngredient(first);
    expect(_sheetState(container).mealIngredients, [first]);

    controller.updateMealIngredient(first, second);
    expect(_sheetState(container).mealIngredients, [second]);

    controller.clearMealIngredients();
    expect(_sheetState(container).mealIngredients, isEmpty);

    controller.addMealIngredient(second);
    controller.removeMealIngredient(second);
    expect(_sheetState(container).mealIngredients, isEmpty);
  });

  test('sets low treatment draft ingredient from quick item', () async {
    final controller = await _readyController(container);
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
      gramsPerPortion: 3,
    );

    controller.setQuickLowTreatmentItem(quickItem, 2);

    final ingredients = _sheetState(container).mealIngredients;

    expect(ingredients, hasLength(1));
    expect(ingredients.single.ingredient.name, 'Dextro');
    expect(ingredients.single.amount, 4);
    expect(ingredients.single.ingredientPortion.amount, 3);
  });

  test('saves current low treatment draft with ingredients', () async {
    final controller = await _readyController(container);
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

  test('auto attaches latest meal from last three hours', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Stary posiłek',
            plannedAt: now
                .subtract(const Duration(hours: 3, minutes: 1))
                .millisecondsSinceEpoch,
          ),
        );
    final relatedMeal = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Obiad',
            plannedAt: now
                .subtract(const Duration(minutes: 45))
                .millisecondsSinceEpoch,
            status: const drift.Value('summarized'),
          ),
        );
    await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Zaplanowany posiłek',
            plannedAt: now
                .subtract(const Duration(minutes: 5))
                .millisecondsSinceEpoch,
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedMealId, relatedMeal.id);
  });

  test('auto attaches active activity log', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    final activity = await db
        .into(db.activity)
        .insertReturning(
          ActivityCompanion.insert(
            name: 'Rower',
            percentagePre: 30,
            percentagePost: 20,
          ),
        );
    final activityLog = await db
        .into(db.activityLog)
        .insertReturning(
          ActivityLogCompanion.insert(
            activityId: activity.id,
            startedAt: now
                .subtract(const Duration(minutes: 15))
                .millisecondsSinceEpoch,
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedActivityLogId, activityLog.id);
    expect(context.reason, LowTreatmentReason.plannedActivity);
  });

  test(
    'switches between cached related activity and meal candidates',
    () async {
      final now = DateTime(2026, 5, 24, 11, 30);
      final relatedMeal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Obiad',
              plannedAt: now
                  .subtract(const Duration(minutes: 45))
                  .millisecondsSinceEpoch,
              status: const drift.Value('summarized'),
            ),
          );
      final activity = await db
          .into(db.activity)
          .insertReturning(
            ActivityCompanion.insert(
              name: 'Rower',
              percentagePre: 30,
              percentagePost: 20,
            ),
          );
      final activityLog = await db
          .into(db.activityLog)
          .insertReturning(
            ActivityLogCompanion.insert(
              activityId: activity.id,
              startedAt: now
                  .subtract(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            ),
          );

      await withClock(Clock.fixed(now), () async {
        final controller = await _readyController(container);
        var sheetState = _sheetState(container);

        expect(sheetState.contextDraft.relatedActivityLogId, activityLog.id);
        expect(sheetState.canSwitchToRelatedMeal, isTrue);

        controller.switchRelatedContext();
        sheetState = _sheetState(container);

        expect(sheetState.contextDraft.relatedMealId, relatedMeal.id);
        expect(sheetState.contextDraft.relatedActivityLogId, isNull);
        expect(sheetState.canSwitchToRelatedActivity, isTrue);

        controller.switchRelatedContext();
        sheetState = _sheetState(container);

        expect(sheetState.contextDraft.relatedMealId, isNull);
        expect(sheetState.contextDraft.relatedActivityLogId, activityLog.id);
      });
    },
  );

  test('does not auto attach stale open activity log', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    final activity = await db
        .into(db.activity)
        .insertReturning(
          ActivityCompanion.insert(
            name: 'Rower',
            percentagePre: 30,
            percentagePost: 20,
            durationMinutes: const drift.Value(30),
          ),
        );
    await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activity.id,
            startedAt: now
                .subtract(const Duration(minutes: 45))
                .millisecondsSinceEpoch,
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedActivityLogId, isNull);
  });

  test('does not auto attach recently ended activity log', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    final activity = await db
        .into(db.activity)
        .insertReturning(
          ActivityCompanion.insert(
            name: 'Rower',
            percentagePre: 30,
            percentagePost: 20,
            durationMinutes: const drift.Value(30),
          ),
        );
    await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activity.id,
            startedAt: now
                .subtract(const Duration(minutes: 45))
                .millisecondsSinceEpoch,
            endedAt: drift.Value(
              now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch,
            ),
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedActivityLogId, isNull);
  });

  test(
    'disables meal switch when activity is attached without recent meal',
    () async {
      final now = DateTime(2026, 5, 24, 11, 30);
      final activity = await db
          .into(db.activity)
          .insertReturning(
            ActivityCompanion.insert(
              name: 'Rower',
              percentagePre: 30,
              percentagePost: 20,
            ),
          );
      await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activity.id,
              startedAt: now
                  .subtract(const Duration(minutes: 15))
                  .millisecondsSinceEpoch,
            ),
          );

      final sheetState = await withClock(Clock.fixed(now), () async {
        final controller = await _readyController(container);

        await container.pump();
        controller.switchRelatedContext();
        return _sheetState(container);
      });

      expect(sheetState.relatedActivityLog, isNotNull);
      expect(sheetState.canSwitchToRelatedMeal, isFalse);
    },
  );

  test(
    'disables activity switch when meal is attached without recent activity',
    () async {
      final now = DateTime(2026, 5, 24, 11, 30);
      await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Obiad',
              plannedAt: now
                  .subtract(const Duration(minutes: 45))
                  .millisecondsSinceEpoch,
              status: const drift.Value('summarized'),
            ),
          );

      final sheetState = await withClock(Clock.fixed(now), () async {
        final controller = await _readyController(container);

        await container.pump();
        controller.switchRelatedContext();
        return _sheetState(container);
      });

      expect(sheetState.relatedMeal, isNotNull);
      expect(sheetState.canSwitchToRelatedActivity, isFalse);
    },
  );

  test('does not auto attach activity after detaching it', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    final activity = await db
        .into(db.activity)
        .insertReturning(
          ActivityCompanion.insert(
            name: 'Rower',
            percentagePre: 30,
            percentagePost: 20,
          ),
        );
    await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activity.id,
            startedAt: now
                .subtract(const Duration(minutes: 15))
                .millisecondsSinceEpoch,
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.detachRelatedContext();
      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedActivityLogId, isNull);
  });

  test('does not auto attach latest meal after detaching it', () async {
    final now = DateTime(2026, 5, 24, 11, 30);
    await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'Obiad',
            plannedAt: now
                .subtract(const Duration(minutes: 45))
                .millisecondsSinceEpoch,
          ),
        );
    final ingredient = _ingredientDraft(name: 'Glukoza', carbsPer100g: 100);

    final context = await withClock(Clock.fixed(now), () async {
      final controller = await _readyController(container);

      controller.detachRelatedContext();
      controller.addMealIngredient(ingredient);
      return controller.saveCurrentDraft();
    });

    expect(context.relatedMealId, isNull);
  });

  test('keeps use case providers alive while saving context', () async {
    final subscription = container.listen(
      lowTreatmentContextControllerProvider,
      (_, _) {},
    );
    final controller = await _readyController(container);
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
    final controller = await _readyController(container);
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

Future<LowTreatmentContextController> _readyController(
  ProviderContainer container,
) async {
  container.listen(lowTreatmentContextControllerProvider, (_, _) {});
  await container.read(lowTreatmentContextControllerProvider.future);
  return container.read(lowTreatmentContextControllerProvider.notifier);
}

LowTreatmentSheetState _sheetState(ProviderContainer container) {
  return container.read(lowTreatmentContextControllerProvider).value!;
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
