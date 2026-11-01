import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/quick_low_treatment_items_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves a shortcut before its management list has loaded', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final controller = container.read(
      quickLowTreatmentItemsControllerProvider.notifier,
    );
    await controller.upsertSlot(
      slot: 1,
      mealIngredient: _ingredientDraft(
        name: 'TEST Juice',
        carbsPer100g: 10,
        portionName: 'glass',
        gramsPerPortion: 200,
        amount: 0.5,
      ),
    );
    final items = await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems();
    expect(items, hasLength(1));
    expect(items.single.name, 'TEST Juice');
    expect(items.single.amount, 0.5);
  });
  test('changing shortcut quantity preserves additional ingredients', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        lowTreatmentContextControllerProvider.overrideWith(
          () => LowTreatmentContextController(
            historicalAt: DateTime(2026, 10, 31),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final subscription = container.listen(
      lowTreatmentContextControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(lowTreatmentContextControllerProvider.future);
    final controller = container.read(
      lowTreatmentContextControllerProvider.notifier,
    );
    const juice = QuickLowTreatmentItem(
      id: 1,
      name: 'TEST Juice',
      ingredient: Ingredient(
        id: 1,
        name: 'TEST Juice',
        carbsPer100g: 10,
        fatPer100g: 0,
        proteinPer100g: 0,
        fiberPer100g: 0,
        nutritionConfidence: 1,
        isReference: false,
      ),
      portion: null,
      amount: 100,
      sortOrder: 1,
      gramsPerPortion: null,
    );
    final extra = _ingredientDraft(
      name: 'TEST Banana',
      carbsPer100g: 20,
      portionName: 'piece',
      gramsPerPortion: 100,
      amount: 1,
    );
    controller.setQuickLowTreatmentItem(juice, 1);
    controller.addMealIngredient(extra);
    controller.setQuickLowTreatmentItem(juice, 0.5);
    final entries = container
        .read(lowTreatmentContextControllerProvider)
        .requireValue
        .mealIngredients;
    expect(entries, hasLength(2));
    expect(entries.first.amount, 50);
    expect(entries.last, same(extra));
    controller.clearQuickIngredient();
    expect(
      container
          .read(lowTreatmentContextControllerProvider)
          .requireValue
          .mealIngredients,
      [extra],
    );
  });
}

MealIngredientsDraft _ingredientDraft({
  required String name,
  required double carbsPer100g,
  double fatPer100g = 0,
  double proteinPer100g = 0,
  required String portionName,
  required double gramsPerPortion,
  required double amount,
}) {
  return MealIngredientsDraft(
    ingredient: IngredientDraft.draft(
      name: name,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: 0,
      proteinPer100g: proteinPer100g,
      nutritionConfidence: 1,
      isReference: false,
    ),
    ingredientPortion: IngredientPortionDraft(
      portion: PortionSelection.draft(name: portionName, unitHint: 'szt.'),
      amount: gramsPerPortion,
    ),
    amount: amount,
    quantityConfidence: 1,
    entryType: 'planned',
    consumedAmount: null,
    consumedConfidence: null,
  );
}
