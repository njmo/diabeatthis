import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_extra_item_portion_resolver.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resolves existing portion grams before calculating extra carbs',
    () async {
      final item = MealIngredientsDraft(
        ingredient: Ingredient.existing(
          id: 1,
          name: 'Jabłko',
          carbsPer100g: 12,
          fatPer100g: 0,
          fiberPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: PortionSelection.existing(
            id: 10,
            name: 'sztuka',
            unitHint: 'g',
          ),
          amount: 0,
        ),
        amount: 1,
        quantityConfidence: 1,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );

      expect(calculateExtraItemNetCarbs(item), 0);

      final resolved = await resolveMealSummaryExtraItemPortionAmount(
        item: item,
        loadPortionAmount: () async => 100,
      );

      expect(resolved.ingredientPortion.amount, 100);
      expect(calculateExtraItemNetCarbs(resolved), 12);
    },
  );
}
