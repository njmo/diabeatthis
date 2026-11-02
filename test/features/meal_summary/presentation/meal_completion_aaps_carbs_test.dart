import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_completion_aaps_carbs.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_completion_shortfall.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_aaps_suggestion.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'half of an original ingredient never submits negative carbs or eCarbs',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, consumed: 50),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 0);
      expect(result.extendedCarbs, 0);
      expect(
        mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
        isFalse,
      );
      expect(
        buildMealSummaryAapsSuggestionEvent(
          aapsCarbs: result,
          extendedCarbsScheduleSettings: null,
        ),
        isNull,
      );
      expect(draft.itemsById[1]!.consumedAmount, 50);
      expect(draft.itemsById[1]!.reportedAmount, 100);
    },
  );

  test(
    'doubling an original ingredient adds only the eCarbs above its report',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, consumed: 200),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 20);
      expect(result.extendedCarbs, 11);
      expect(
        mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
        isTrue,
      );
      expect(
        mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: false),
        isFalse,
      );
      // The older editor keeps its existing extra-products-only contract.
      expect(calculateMealSummaryAapsCarbs(draft).extendedCarbs, 0);
    },
  );

  test(
    'mixed original ingredient changes combine net carbs and actual macros',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, consumed: 50, netCarbs: 0.3, fat: 0, protein: 0),
        completionCarbsItem(2, consumed: 200),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 5);
      expect(result.extendedCarbs, 11);
      expect(
        mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
        isTrue,
      );
    },
  );

  test(
    'more fat with fewer carbohydrates preserves the shortfall review guard',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, consumed: 50, netCarbs: 0.3, fat: 0, protein: 0),
        completionCarbsItem(2, consumed: 200, netCarbs: 0.05),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 0);
      expect(result.extendedCarbs, 11);
      expect(
        mealCompletionNeedsShortfallReview(draft, hasRecordedBolus: true),
        isTrue,
      );
      expect(
        mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
        isFalse,
      );
    },
  );

  test(
    'an add-on uses the latest reported quantity instead of the original plan',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, reported: 200, consumed: 300),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 20);
      expect(result.extendedCarbs, 11);
      expect(draft.itemsById[1]!.plannedAmount, 100);
      expect(draft.itemsById[1]!.reportedAmount, 200);
    },
  );

  test(
    'persisted extra products participate in the reported macro baseline',
    () {
      final draft = completionCarbsDraft([
        completionCarbsItem(1, reported: 200, consumed: 300),
        completionCarbsItem(
          2,
          planned: 0,
          reported: 100,
          consumed: 200,
          extra: true,
        ),
      ]);
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 40);
      expect(result.extendedCarbs, 22);
    },
  );

  test(
    'new extra products count once while the existing meal is the baseline',
    () {
      final extra = completionCarbsExtra(
        2,
        amount: 100,
        fat: 10,
        protein: 5,
        carbs: 20,
      );
      final draft = completionCarbsDraft(
        [completionCarbsItem(1)],
        extras: [extra],
      );
      final result = calculateMealCompletionAapsCarbs(draft);
      expect(result.carbs, 20);
      expect(result.extendedCarbs, 11);
      expect(draft.extraItems, [extra]);

      final reloaded = completionCarbsDraft([
        completionCarbsItem(1),
        completionCarbsItem(2, planned: 0, extra: true),
      ]);
      final repeated = calculateMealCompletionAapsCarbs(reloaded);
      expect(repeated.carbs, 0);
      expect(repeated.extendedCarbs, 0);
      expect(
        mealCompletionCanOpenAapsSuggestion(reloaded, hasRecordedBolus: true),
        isFalse,
      );
    },
  );

  test('a new product can cross the total meal WBT threshold on its own', () {
    final draft = completionCarbsDraft(
      [completionCarbsItem(1, netCarbs: 0, fat: 0.1, protein: 0)],
      extras: [completionCarbsExtra(2, amount: 100, fat: 2)],
    );
    final result = calculateMealCompletionAapsCarbs(draft);
    expect(result.carbs, 0);
    expect(result.extendedCarbs, 11);
    expect(
      mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
      isTrue,
    );
    expect(calculateMealSummaryAapsCarbs(draft).extendedCarbs, 0);
  });

  test(
    'the existing strict WBT threshold and rounding apply before subtraction',
    () {
      final atThreshold = completionCarbsDraft([
        completionCarbsItem(1, netCarbs: 0, fat: 0, protein: 0.25),
      ]);
      expect(calculateMealCompletionAapsCarbs(atThreshold).extendedCarbs, 0);
      final justAbove = completionCarbsDraft([
        completionCarbsItem(
          1,
          consumed: 101,
          netCarbs: 0,
          fat: 0,
          protein: 0.25,
        ),
      ]);
      expect(calculateMealCompletionAapsCarbs(justAbove).extendedCarbs, 11);
      final smallIncrease = completionCarbsDraft([
        completionCarbsItem(1, consumed: 101, netCarbs: 0),
      ]);
      expect(calculateMealCompletionAapsCarbs(smallIncrease).extendedCarbs, 1);
    },
  );
}

MealSummaryDraft completionCarbsDraft(
  List<MealSummaryItemDraft> items, {
  List<MealIngredientsDraft> extras = const [],
}) => MealSummaryDraft(
  mealId: 1,
  mealStatus: 'bolused-eating',
  itemIds: items.map((item) => item.mealIngredientId).toList(),
  itemsById: {for (final item in items) item.mealIngredientId: item},
  extraItems: extras,
);

MealSummaryItemDraft completionCarbsItem(
  int id, {
  double planned = 100,
  double reported = 100,
  double? consumed,
  double netCarbs = 0.2,
  double fat = 0.1,
  double protein = 0.05,
  bool extra = false,
}) => MealSummaryItemDraft(
  name: 'Product $id',
  mealIngredientId: id,
  plannedAmount: planned,
  reportedAmount: reported,
  amountLabel: 'g',
  netCarbsPerAmount: netCarbs,
  consumedAmount: consumed ?? reported,
  consumedConfidence: 1,
  gramsPerAmount: 1,
  fatPerAmount: fat,
  proteinPerAmount: protein,
  isExtra: extra,
);

MealIngredientsDraft completionCarbsExtra(
  int id, {
  required double amount,
  double carbs = 0,
  double fat = 0,
  double protein = 0,
}) => MealIngredientsDraft(
  mealIngredientId: id,
  ingredient: IngredientDraft.existing(
    id: id,
    name: 'Extra $id',
    carbsPer100g: carbs,
    fatPer100g: fat,
    proteinPer100g: protein,
    fiberPer100g: 0,
    nutritionConfidence: 1,
    isReference: false,
  ),
  ingredientPortion: const IngredientPortionDraft(
    portion: PortionSelection.empty(),
    amount: 1,
  ),
  amount: amount,
  quantityConfidence: 1,
  entryType: 'extra',
  consumedAmount: amount,
  consumedConfidence: 1,
);
