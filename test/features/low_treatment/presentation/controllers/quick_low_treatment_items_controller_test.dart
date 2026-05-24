import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/quick_low_treatment_items_controller.dart';
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

  test(
    'creates, updates, swaps and deletes quick low treatment items',
    () async {
      final subscription = container.listen(
        quickLowTreatmentItemsControllerProvider,
        (_, _) {},
      );
      final controller = container.read(
        quickLowTreatmentItemsControllerProvider.notifier,
      );
      await container.read(quickLowTreatmentItemsControllerProvider.future);

      await controller.upsertSlot(
        slot: 3,
        mealIngredient: _ingredientDraft(
          name: 'Dextro',
          carbsPer100g: 90,
          portionName: 'cukierek',
          gramsPerPortion: 3,
          amount: 2,
        ),
      );
      await container.pump();

      var state = container
          .read(quickLowTreatmentItemsControllerProvider)
          .requireValue;
      var item = state.slots[2].item;

      expect(state.slots, hasLength(6));
      expect(item?.name, 'Dextro');
      expect(item?.sortOrder, 3);
      expect(item?.portion?.name, 'cukierek');
      expect(item?.gramsPerPortion, 3);

      await controller.upsertSlot(
        slot: 3,
        existingItem: item,
        mealIngredient: _ingredientDraft(
          name: 'Żel',
          carbsPer100g: 60,
          portionName: 'saszetka',
          gramsPerPortion: 25,
          amount: 1,
        ),
      );
      await container.pump();

      state = container
          .read(quickLowTreatmentItemsControllerProvider)
          .requireValue;
      item = state.slots[2].item;

      expect(item?.name, 'Żel');
      expect(item?.id, 1);

      await controller.upsertSlot(
        slot: 1,
        mealIngredient: _ingredientDraft(
          name: 'Sok jabłkowy',
          carbsPer100g: 11,
          portionName: 'porcja',
          gramsPerPortion: 100,
          amount: 1,
        ),
      );
      await container.pump();

      state = container
          .read(quickLowTreatmentItemsControllerProvider)
          .requireValue;
      await controller.swapSlots(
        source: state.slots[0],
        target: state.slots[2],
      );
      await container.pump();

      state = container
          .read(quickLowTreatmentItemsControllerProvider)
          .requireValue;

      expect(state.slots[0].item?.name, 'Żel');
      expect(state.slots[2].item?.name, 'Sok jabłkowy');

      await controller.deleteItem(state.slots[0].item!);
      await container.pump();

      state = container
          .read(quickLowTreatmentItemsControllerProvider)
          .requireValue;

      expect(state.slots[0].item, isNull);
      expect(
        await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems(),
        hasLength(1),
      );
      subscription.close();
    },
  );

  test('rejects quick items without energy macros', () async {
    final controller = container.read(
      quickLowTreatmentItemsControllerProvider.notifier,
    );
    await container.read(quickLowTreatmentItemsControllerProvider.future);

    await expectLater(
      controller.upsertSlot(
        slot: 1,
        mealIngredient: _ingredientDraft(
          name: 'Pusty składnik',
          carbsPer100g: 0,
          fatPer100g: 0,
          proteinPer100g: 0,
          portionName: 'porcja',
          gramsPerPortion: 10,
          amount: 1,
        ),
      ),
      throwsArgumentError,
    );

    expect(await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems(), []);
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
