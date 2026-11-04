import 'package:diabeatthis/common/widgets/confidence_slider.dart';
import 'package:diabeatthis/common/widgets/macronutrient_proportions.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review_content.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  const ingredient = IngredientDraft.existing(
    id: 41,
    name: 'Apple',
    carbsPer100g: 12,
    fatPer100g: 0.2,
    fiberPer100g: 2,
    proteinPer100g: 0.3,
    nutritionConfidence: 0.75,
    isReference: false,
    iconAssetPath: 'assets/icons/food/prepared_meal.png',
  );
  const draft = MealIngredientsDraft(
    ingredient: ingredient,
    ingredientPortion: IngredientPortionDraft(
      portion: PortionSelection.existing(id: 42, name: 'sztuka', unitHint: 'g'),
      amount: 150,
    ),
    amount: 2,
    quantityConfidence: 0.5,
    entryType: 'planned',
    consumedAmount: null,
    consumedConfidence: null,
  );

  Future<void> showReview(
    WidgetTester tester,
    MealIngredientsDraft value,
    double gramsPerPortion,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MealIngredientReviewContent(
              draft: value,
              gramsPerPortion: gramsPerPortion,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'review identifies the portion, multiplier, weight, all macros and combined confidence',
    (tester) async {
      await showReview(tester, draft, 150);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('1 × sztuka = 150 g'), findsOneWidget);
      expect(find.text('2 × sztuka · 300 g'), findsOneWidget);
      expect(find.text('36 g'), findsOneWidget);
      expect(find.text('0 g'), findsOneWidget);
      final proportions = tester.widget<MacronutrientProportions>(
        find.byType(MacronutrientProportions),
      );
      expect(proportions.proteinGrams, closeTo(0.9, 0.001));
      expect(proportions.fatGrams, closeTo(0.6, 0.001));
      expect(find.text('153 kcal'), findsOneWidget);
      expect(find.text('Łączna pewność'), findsOneWidget);
      expect(find.text('Średnia (61%)'), findsOneWidget);
      expect(find.byType(ConfidenceSlider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reference review uses live macros and portion count without physical mass',
    (tester) async {
      final reference = draft.copyWith(
        ingredient: ingredient.copyWith(
          name: 'Reference dish',
          isReference: true,
          carbsPer100g: 40,
          proteinPer100g: 25,
          fatPer100g: 100 / 9,
          fiberPer100g: 0,
          wbtKcalPer100g: 999,
          kcalPer100g: 999,
        ),
        ingredientPortion: const IngredientPortionDraft(
          portion: PortionSelection.empty(),
          amount: 100,
        ),
        amount: 1.5,
      );
      await showReview(tester, reference, 100);
      expect(find.text('1,5 × porcja'), findsOneWidget);
      expect(find.text('60 g'), findsOneWidget);
      expect(find.text('30 g'), findsOneWidget);
      final proportions = tester.widget<MacronutrientProportions>(
        find.byType(MacronutrientProportions),
      );
      expect(proportions.proteinGrams, 37.5);
      expect(proportions.fatGrams, closeTo(16.6667, 0.001));
      expect(find.text('540 kcal'), findsOneWidget);
      expect(find.textContaining('100 g'), findsNothing);
      expect(find.text('150 g'), findsNothing);
      expect(find.text('Średnia (61%)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
