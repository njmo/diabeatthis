import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts reduced planned portions as negative carbs', () {
    final delta = calculateMealSummaryCarbsDelta(
      MealSummaryDraft(
        mealId: 1,
        mealStatus: 'eaten',
        itemIds: const [1],
        itemsById: {
          1: _item(
            id: 1,
            plannedAmount: 2,
            consumedAmount: 1,
            netCarbsPerAmount: 12,
          ),
        },
        extraItems: const [],
      ),
    );

    expect(delta.plannedItemsDelta, -12);
    expect(delta.extraItemsCarbs, 0);
    expect(delta.roundedTotal, -12);
    expect(delta.isNegative, isTrue);
  });

  test('combines planned portion changes and add-on items into one delta', () {
    final delta = calculateMealSummaryCarbsDelta(
      MealSummaryDraft(
        mealId: 1,
        mealStatus: 'eaten',
        itemIds: const [1, 2],
        itemsById: {
          1: _item(
            id: 1,
            plannedAmount: 1,
            consumedAmount: 0.5,
            netCarbsPerAmount: 10,
          ),
          2: _item(
            id: 2,
            plannedAmount: 1,
            consumedAmount: 2,
            netCarbsPerAmount: 8,
          ),
        },
        extraItems: [
          _extraItem(amount: 100, carbsPer100g: 20, fiberPer100g: 5),
        ],
      ),
    );

    expect(delta.plannedItemsDelta, 3);
    expect(delta.extraItemsCarbs, 15);
    expect(delta.roundedTotal, 18);
    expect(delta.isPositive, isTrue);
  });

  test('treats unchanged meal as neutral', () {
    final delta = calculateMealSummaryCarbsDelta(
      MealSummaryDraft(
        mealId: 1,
        mealStatus: 'eaten',
        itemIds: const [1],
        itemsById: {
          1: _item(
            id: 1,
            plannedAmount: 1,
            consumedAmount: 1,
            netCarbsPerAmount: 10,
          ),
        },
        extraItems: const [],
      ),
    );

    expect(delta.roundedTotal, 0);
    expect(delta.isNeutral, isTrue);
  });
}

MealSummaryItemDraft _item({
  required int id,
  required double plannedAmount,
  required double consumedAmount,
  required double netCarbsPerAmount,
}) {
  return MealSummaryItemDraft(
    mealIngredientId: id,
    name: 'Item $id',
    plannedAmount: plannedAmount,
    amountLabel: 'porcja',
    netCarbsPerAmount: netCarbsPerAmount,
    consumedAmount: consumedAmount,
    consumedConfidence: 1,
  );
}

MealIngredientsDraft _extraItem({
  required double amount,
  required double carbsPer100g,
  required double fiberPer100g,
}) {
  return MealIngredientsDraft(
    mealIngredientId: null,
    ingredient: Ingredient.existing(
      id: 1,
      name: 'Extra',
      carbsPer100g: carbsPer100g,
      fatPer100g: 0,
      fiberPer100g: fiberPer100g,
      proteinPer100g: 0,
      nutritionConfidence: 1,
      isReference: false,
    ),
    ingredientPortion: IngredientPortionDraft(
      portion: PortionSelection.empty(),
      amount: 1,
    ),
    amount: amount,
    quantityConfidence: 1,
    entryType: 'extra',
    consumedAmount: amount,
    consumedConfidence: 1,
  );
}
