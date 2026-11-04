import 'package:diabeatthis/common/widgets/form_action_bar.dart';
import 'package:diabeatthis/common/widgets/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_nutrition_totals_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_review_nutrition.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

const reviewRow = MealIngredientsDraft(
  ingredient: IngredientDraft.existing(
    id: 1,
    name: 'US food',
    carbsPer100g: 20,
    fiberPer100g: 5,
    proteinPer100g: 10,
    fatPer100g: 10,
    nutritionConfidence: .75,
    carbsLabelMode: CarbsLabelMode.nonEu,
    isReference: false,
  ),
  ingredientPortion: IngredientPortionDraft(
    portion: PortionSelection.empty(),
    amount: 1,
  ),
  amount: 150,
  quantityConfidence: .5,
  entryType: 'planned',
  consumedAmount: null,
  consumedConfidence: null,
);

void main() {
  test(
    'draft display uses raw nutrition and recorded physical weights',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        reviewRow,
        reviewRow.copyWith(
          ingredient: reviewRow.ingredient.copyWith(
            name: 'EU food',
            carbsPer100g: 10,
            fiberPer100g: 20,
            proteinPer100g: 5,
            fatPer100g: 0,
            carbsLabelMode: CarbsLabelMode.eu,
          ),
          amount: 2,
          recordedGramsPerAmount: 35,
        ),
      ]);
      final totals = await container.read(
        mealDraftNutritionTotalsProvider.future,
      );
      expect(totals.totalGrams, 220);
      expect(totals.totalNetCarbsG, 29.5);
      expect(totals.totalFiberG, 21.5);
      expect(totals.totalProteinG, 18.5);
      expect(totals.totalCaloriesKcal, 327);
    },
  );

  testWidgets(
    'planning review reuses shared macros and updates calories and mass',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        reviewRow,
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(child: MealReviewNutrition()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Makroskładniki posiłku'), findsOneWidget);
      expect(find.byType(MealMacroSummary), findsOneWidget);
      expect(find.text('285 kcal'), findsOneWidget);
      expect(find.text('· 150 g'), findsOneWidget);
      expect(find.text('7,5 g'), findsOneWidget);
      final summary = tester.widget<MealMacroSummary>(
        find.byType(MealMacroSummary),
      );
      expect(summary.netCarbs, 22.5);
      expect(summary.fiber, 7.5);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        reviewRow.copyWith(amount: 200),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('380 kcal'), findsOneWidget);
      expect(find.text('· 200 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'add meal uses the same action bar clearance above Android navigation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: localizedMaterialApp(
            home: const MediaQuery(
              data: MediaQueryData(padding: EdgeInsets.only(bottom: 24)),
              child: AddMealPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = find.byType(FormActionBar);
      expect(bar, findsOneWidget);
      final actions = find
          .descendant(of: bar, matching: find.byType(Row))
          .first;
      expect(
        tester.getBottomRight(bar).dy - tester.getBottomRight(actions).dy,
        48,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
