import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_completion_shortfall.dart';
import 'package:flutter_test/flutter_test.dart';

MealSummaryDraft roundedCoverageDraft(double actualCarbs) => MealSummaryDraft(
  mealId: 1,
  mealStatus: 'eating-extra',
  itemIds: const [1],
  itemsById: {
    1: MealSummaryItemDraft(
      name: 'Food',
      mealIngredientId: 1,
      plannedAmount: 30,
      reportedAmount: 49.1,
      consumedAmount: actualCarbs,
      consumedConfidence: 1,
      amountLabel: 'g',
      netCarbsPerAmount: 1,
    ),
  },
  extraItems: const [],
);

void main() {
  test(
    'eating the whole reported amount matches its rounded calculator request',
    () {
      final draft = roundedCoverageDraft(49.1);

      expect(mealCompletionShortfallCarbs(draft, coveredNetCarbs: 50), 0);
      expect(
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: true,
          coveredNetCarbs: 50,
        ),
        isFalse,
      );
    },
  );

  test(
    'a genuine reduction still reviews the uncovered food in calculator grams',
    () {
      final draft = roundedCoverageDraft(39.1);

      expect(mealCompletionShortfallCarbs(draft, coveredNetCarbs: 50), 10);
      expect(
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: true,
          coveredNetCarbs: 50,
        ),
        isTrue,
      );
    },
  );

  test(
    'ordinary summaries preserve the existing exact reported-baseline comparison',
    () {
      final draft = roundedCoverageDraft(48.2);

      expect(mealCompletionShortfallCarbs(draft), closeTo(0.9, 0.000001));
      expect(
        mealCompletionNeedsShortfallReview(draft, hasRecordedBolus: true),
        isTrue,
      );
    },
  );
}
