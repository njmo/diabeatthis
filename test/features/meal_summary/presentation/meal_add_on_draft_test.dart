import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_add_on_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final multiplier in [1.5, 2.0]) {
    test(
      '$multiplier preset is the total planned portion with estimated confidence',
      () {
        final original = addOnDraft();
        final draft = prepareMealAddOnDraft(
          original,
          totalMultiplier: multiplier,
        );
        expect(draft.itemsById[1]!.consumedAmount, multiplier);
        expect(draft.itemsById[2]!.consumedAmount, 200 * multiplier);
        expect(draft.itemsById[1]!.consumedConfidence, 0.75);
        expect(draft.itemsById[2]!.consumedConfidence, 0.75);
        expect(draft.itemsById[1]!.reportedAmount, 1);
        expect(original.itemsById[1]!.consumedAmount, 1);
        expect(mealAddOnAmountsValid(draft), isTrue);
      },
    );
  }

  test(
    'presets do not reduce a previously reported larger serving or multiply old extras',
    () {
      final original = addOnDraft(reportedMeatballs: 3, savedExtra: true);
      final draft = prepareMealAddOnDraft(original, totalMultiplier: 2);
      expect(draft.itemsById[1]!.consumedAmount, 3);
      expect(draft.itemsById[1]!.consumedConfidence, 0.5);
      expect(draft.itemsById[3]!.consumedAmount, 50);
      expect(draft.itemsById[3]!.consumedConfidence, 0.5);
    },
  );

  test(
    'manual starts from reported totals and requires an actual increase',
    () {
      final draft = prepareMealAddOnDraft(addOnDraft(reportedMeatballs: 1.5));
      expect(draft.itemsById[1]!.consumedAmount, 1.5);
      expect(draft.itemsById[2]!.consumedAmount, 200);
      expect(mealAddOnAmountsValid(draft), isFalse);
      final adjusted = draft.copyWith(
        itemsById: {
          ...draft.itemsById,
          1: draft.itemsById[1]!.copyWith(
            consumedAmount: 2,
            consumedConfidence: 1,
          ),
        },
      );
      expect(mealAddOnAmountsValid(adjusted), isTrue);
      expect(adjusted.itemsById[2]!.consumedAmount, 200);
    },
  );

  test('add-on rejects a decrease even when another ingredient increases', () {
    final draft = addOnDraft();
    final mixed = draft.copyWith(
      itemsById: {
        1: draft.itemsById[1]!.copyWith(consumedAmount: 2),
        2: draft.itemsById[2]!.copyWith(consumedAmount: 100),
      },
    );
    expect(mealAddOnAmountsValid(mixed), isFalse);
  });

  test('invalid amounts cannot be saved as extra food', () {
    final draft = addOnDraft();
    for (final value in [double.nan, double.infinity, -1.0]) {
      expect(
        mealAddOnAmountsValid(
          draft.copyWith(
            itemsById: {
              ...draft.itemsById,
              1: draft.itemsById[1]!.copyWith(consumedAmount: value),
            },
          ),
        ),
        isFalse,
      );
    }
  });
}

MealSummaryDraft addOnDraft({
  double reportedMeatballs = 1,
  bool savedExtra = false,
}) => MealSummaryDraft(
  mealId: 1,
  mealStatus: 'eating',
  itemIds: [1, 2, if (savedExtra) 3],
  itemsById: {
    1: addOnItem(
      1,
      'Meatball',
      planned: 1,
      reported: reportedMeatballs,
      label: 'portion',
    ),
    2: addOnItem(2, 'Potatoes', planned: 200, reported: 200),
    if (savedExtra)
      3: addOnItem(3, 'Sauce', planned: 50, reported: 50, extra: true),
  },
  extraItems: [],
);

MealSummaryItemDraft addOnItem(
  int id,
  String name, {
  required double planned,
  required double reported,
  String label = 'g',
  bool extra = false,
}) => MealSummaryItemDraft(
  name: name,
  mealIngredientId: id,
  plannedAmount: planned,
  reportedAmount: reported,
  amountLabel: label,
  netCarbsPerAmount: 0.2,
  consumedAmount: reported,
  consumedConfidence: 0.5,
  gramsPerAmount: label == 'g' ? 1 : 80,
  isExtra: extra,
);
