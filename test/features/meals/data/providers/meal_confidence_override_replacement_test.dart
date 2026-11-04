import 'package:diabeatthis/common/widgets/confidence_indicator.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review_content.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

const reviewedIngredient = IngredientDraft.existing(
  id: 7,
  name: 'Rice',
  carbsPer100g: 20,
  fiberPer100g: 2,
  fatPer100g: 1,
  proteinPer100g: 3,
  nutritionConfidence: 0,
  isReference: false,
  iconAssetPath: 'assets/icons/food/prepared_meal.png',
);
const reviewedRow = MealIngredientsDraft(
  ingredient: reviewedIngredient,
  ingredientPortion: IngredientPortionDraft(
    portion: PortionSelection.empty(),
    amount: 1,
  ),
  amount: 100,
  quantityConfidence: .5,
  nutritionConfidenceOverride: .75,
  entryType: 'planned',
  consumedAmount: null,
  consumedConfidence: null,
);

void main() {
  test(
    'same ingredient keeps reviewed confidence and replacement clears it',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final listener = container.listen(
        mealIngredientsDraftProvider,
        (_, _) {},
      );
      addTearDown(listener.close);
      final editor = container.read(mealIngredientsDraftProvider.notifier);
      editor.overrideMealIngredient(reviewedRow);
      editor.setIngredient(reviewedIngredient);
      expect(
        container
            .read(mealIngredientsDraftProvider)
            .nutritionConfidenceOverride,
        .75,
      );
      editor.setIngredient(
        reviewedIngredient.copyWith(name: 'Different facts', proteinPer100g: 4),
      );
      expect(
        container
            .read(mealIngredientsDraftProvider)
            .nutritionConfidenceOverride,
        isNull,
      );
    },
  );

  testWidgets('copied photo row displays its reviewed confidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: MealIngredientReviewContent(
                draft: reviewedRow,
                gramsPerPortion: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final indicator = tester.widget<ConfidenceIndicator>(
      find.byType(ConfidenceIndicator),
    );
    expect(indicator.value, closeTo(.6123724356957945, 1e-12));
  });
}
