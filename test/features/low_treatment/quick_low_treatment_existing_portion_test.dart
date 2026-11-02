import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/upsert_quick_low_treatment_item_use_case.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_selector.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_tile.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  late int ingredientId;
  late int portionId;

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    ingredientId = await db
        .into(db.ingredient)
        .insert(
          IngredientCompanion.insert(
            name: 'TEST Glucose',
            carbsPer100g: 100,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            iconAssetPath: const Value('assets/icons/food/prepared_meal.png'),
          ),
        );
    portionId = await db
        .into(db.portion)
        .insert(PortionCompanion.insert(name: 'piece', unitHint: 'g'));
    await db.insertIngredientPortion(ingredientId, portionId, 5);
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  MealIngredientsDraft draft({double portionWeight = 0}) =>
      MealIngredientsDraft(
        ingredient: IngredientDraft.existing(
          id: ingredientId,
          name: 'TEST Glucose',
          carbsPer100g: 100,
          fatPer100g: 0,
          fiberPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
          iconAssetPath: 'assets/icons/food/prepared_meal.png',
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: PortionSelection.existing(
            id: portionId,
            name: 'piece',
            unitHint: 'g',
          ),
          amount: portionWeight,
        ),
        amount: 2,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );

  test('shortcut resolves the stored weight of an existing portion', () async {
    final item = await container
        .read(upsertQuickLowTreatmentItemUseCaseProvider)
        .call(slot: 1, mealIngredient: draft());
    expect(item.name, 'TEST Glucose');
    expect(item.amount, 2);
    expect(item.gramsPerPortion, 5);
    expect(item.portion?.id, portionId);
  });

  test('an explicitly invalid portion weight is still rejected', () async {
    await expectLater(
      container
          .read(upsertQuickLowTreatmentItemUseCaseProvider)
          .call(slot: 1, mealIngredient: draft(portionWeight: -1)),
      throwsArgumentError,
    );
    expect(
      await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems(),
      isEmpty,
    );
  });

  test('an existing portion without a stored weight is rejected', () async {
    await db.delete(db.ingredientPortions).go();
    await expectLater(
      container
          .read(upsertQuickLowTreatmentItemUseCaseProvider)
          .call(slot: 1, mealIngredient: draft()),
      throwsArgumentError,
    );
    expect(
      await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems(),
      isEmpty,
    );
  });

  test('repeated shortcuts preserve the stored portion weight', () async {
    final subscription = container.listen(
      upsertQuickLowTreatmentItemUseCaseProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final useCase = container.read(upsertQuickLowTreatmentItemUseCaseProvider);
    for (final slot in [1, 2]) {
      await useCase.call(slot: slot, mealIngredient: draft());
    }
    final items = await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems();
    expect(items, hasLength(2));
    expect(items.map((item) => item.gramsPerPortion), everyElement(5));
    expect(items.map((item) => item.amount), everyElement(2));
  });

  testWidgets(
    'existing ingredient with a saved portion appears after confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuickLowTreatmentSelector(onSelected: (_, _) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Dodaj skrót'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST Glucose'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Wybierz TEST Glucose'),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 × sztuka = 5 g'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Podsumowanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj składnik'));
      await tester.pumpAndSettle();
      expect(find.byType(AddMealIngredient), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.byType(QuickLowTreatmentTile), findsOneWidget);
      final items = await db.quickLowTreatmentItemDao
          .getQuickLowTreatmentItems();
      expect(items, hasLength(1));
      expect(items.single.gramsPerPortion, 5);
      expect(items.single.amount, 1);
    },
  );
}
