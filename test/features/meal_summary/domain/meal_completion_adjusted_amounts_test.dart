import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/domain/utils/meal_completion_amounts.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealSummaryDraft draft(
    List<double> amounts, {
    double reported = 100,
    List<MealIngredientsDraft> extras = const [],
  }) => MealSummaryDraft(
    mealId: 1,
    mealStatus: 'eating-then-bolus',
    itemIds: [for (var i = 0; i < amounts.length; i++) i],
    itemsById: {
      for (var i = 0; i < amounts.length; i++)
        i: MealSummaryItemDraft(
          mealIngredientId: i,
          name: 'Food $i',
          plannedAmount: 100,
          reportedAmount: reported,
          consumedAmount: amounts[i],
          amountLabel: 'g',
          gramsPerAmount: 1,
          netCarbsPerAmount: 0.2,
          consumedConfidence: 0.6,
        ),
    },
    extraItems: extras,
  );

  test('adjusted unchanged portions use the reported baseline', () {
    final value = draft([150], reported: 150);
    expect(inferMealCompletionChoice(value), MealCompletionChoice.all);
    expect(
      mealCompletionAmountsValid(value, inferMealCompletionChoice(value)),
      isTrue,
    );
    expect(calculateMealSummaryConsumedCarbs(value), 30);
  });

  test('adjusted reduction infers less and retains actual total', () {
    final value = draft([50, 100]);
    expect(inferMealCompletionChoice(value), MealCompletionChoice.less);
    expect(
      mealCompletionAmountsValid(value, inferMealCompletionChoice(value)),
      isTrue,
    );
    expect(calculateMealSummaryConsumedCarbs(value), 30);
  });

  test(
    'mixed changes remain valid even when total calories do not increase',
    () {
      final value = draft([25, 125]);
      expect(inferMealCompletionChoice(value), MealCompletionChoice.more);
      expect(
        mealCompletionAmountsValid(value, inferMealCompletionChoice(value)),
        isTrue,
      );
      expect(calculateMealSummaryConsumedCarbs(value), 30);
    },
  );

  test('another product is included with named portion conversion', () {
    final value = draft(
      [50],
      extras: [
        MealIngredientsDraft(
          ingredient: const IngredientDraft.existing(
            id: 2,
            name: 'Extra',
            carbsPer100g: 40,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
            isReference: false,
          ),
          ingredientPortion: IngredientPortionDraft(
            portion: PortionSelection.existing(
              id: 1,
              name: 'piece',
              unitHint: 'piece',
            ),
            amount: 25,
          ),
          amount: 2,
          quantityConfidence: 1,
          entryType: 'extra',
          consumedAmount: 2,
          consumedConfidence: 1,
        ),
      ],
    );
    expect(inferMealCompletionChoice(value), MealCompletionChoice.more);
    expect(
      mealCompletionAmountsValid(value, inferMealCompletionChoice(value)),
      isTrue,
    );
    expect(calculateMealSummaryConsumedCarbs(value), 30);
  });

  test('adjusted zero or invalid quantities cannot be saved as eaten', () {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      final value = draft([amount]);
      expect(
        mealCompletionAmountsValid(value, inferMealCompletionChoice(value)),
        isFalse,
      );
    }
  });
}
