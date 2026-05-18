import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
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

    expect(delta.itemAmountDelta, -12);
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

    expect(delta.itemAmountDelta, 3);
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

  test('counts only the difference after a quick add-on was reported', () {
    final delta = calculateMealSummaryCarbsDelta(
      MealSummaryDraft(
        mealId: 1,
        mealStatus: 'eaten-extra',
        itemIds: const [1],
        itemsById: {
          1: _item(
            id: 1,
            plannedAmount: 1,
            reportedAmount: 1.5,
            consumedAmount: 2,
            netCarbsPerAmount: 12,
          ),
        },
        extraItems: const [],
      ),
    );

    expect(delta.itemAmountDelta, 6);
    expect(delta.extraItemsCarbs, 0);
    expect(delta.roundedTotal, 6);
    expect(delta.usesReportedBaseline, isTrue);
  });

  test(
    'combines mixed item corrections and extra ingredients intelligently',
    () {
      final delta = calculateMealSummaryCarbsDelta(
        MealSummaryDraft(
          mealId: 1,
          mealStatus: 'eaten-extra',
          itemIds: const [1, 2],
          itemsById: {
            1: _item(
              id: 1,
              plannedAmount: 1,
              reportedAmount: 1.5,
              consumedAmount: 1,
              netCarbsPerAmount: 10,
            ),
            2: _item(
              id: 2,
              plannedAmount: 1,
              reportedAmount: 1.5,
              consumedAmount: 2,
              netCarbsPerAmount: 8,
            ),
          },
          extraItems: [
            _extraItem(amount: 50, carbsPer100g: 60, fiberPer100g: 4),
          ],
        ),
      );

      expect(delta.itemAmountDelta, -1);
      expect(delta.extraItemsCarbs, 28);
      expect(delta.roundedTotal, 27);
      expect(delta.isPositive, isTrue);
      expect(delta.usesReportedBaseline, isTrue);
    },
  );

  test(
    'supports negative correction after a quick add-on was overreported',
    () {
      final delta = calculateMealSummaryCarbsDelta(
        MealSummaryDraft(
          mealId: 1,
          mealStatus: 'eaten-extra',
          itemIds: const [1],
          itemsById: {
            1: _item(
              id: 1,
              plannedAmount: 1,
              reportedAmount: 2,
              consumedAmount: 1.5,
              netCarbsPerAmount: 16,
            ),
          },
          extraItems: const [],
        ),
      );

      expect(delta.itemAmountDelta, -8);
      expect(delta.roundedTotal, -8);
      expect(delta.isNegative, isTrue);
      expect(delta.usesReportedBaseline, isTrue);
    },
  );

  test('calculates AAPS carbs and e-carbs from summary draft', () {
    final aapsCarbs = calculateMealSummaryAapsCarbs(
      MealSummaryDraft(
        mealId: 1,
        mealStatus: 'eaten',
        itemIds: const [1],
        itemsById: {
          1: _item(
            id: 1,
            plannedAmount: 1,
            consumedAmount: 1.5,
            netCarbsPerAmount: 10,
          ),
        },
        extraItems: [
          _extraItem(
            amount: 100,
            carbsPer100g: 30,
            fiberPer100g: 5,
            fatPer100g: 20,
            proteinPer100g: 10,
          ),
        ],
      ),
    );

    expect(aapsCarbs.carbs, 30);
    expect(aapsCarbs.extendedCarbs, 22);
  });
}

MealSummaryItemDraft _item({
  required int id,
  required double plannedAmount,
  double? reportedAmount,
  required double consumedAmount,
  required double netCarbsPerAmount,
}) {
  return MealSummaryItemDraft(
    mealIngredientId: id,
    name: 'Item $id',
    plannedAmount: plannedAmount,
    reportedAmount: reportedAmount ?? plannedAmount,
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
  double fatPer100g = 0,
  double proteinPer100g = 0,
}) {
  return MealIngredientsDraft(
    mealIngredientId: null,
    ingredient: IngredientDraft.existing(
      id: 1,
      name: 'Extra',
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      proteinPer100g: proteinPer100g,
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
