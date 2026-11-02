import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/presentation/utils/meal_ingredient_portion_formatters.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review_header.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final example in [
    (
      isReference: false,
      isNew: false,
      name: 'Test ingredient',
      portion: 'kromka',
      grams: 35.0,
      expected: '1 × kromka = 35 g',
    ),
    (
      isReference: true,
      isNew: false,
      name: 'Test ingredient',
      portion: 'porcja',
      grams: 100.0,
      expected:
          'Wartości dotyczą jednej porcji referencyjnej. Wybierz liczbę porcji.',
    ),
    (
      isReference: false,
      isNew: true,
      name: 'uyyg',
      portion: 'asd4',
      grams: 1.0,
      expected: '1 × asd4 = 1 g',
    ),
    (
      isReference: false,
      isNew: false,
      name: 'uyyg',
      portion: 'asd4',
      grams: 1.0,
      expected: '1 × asd4 = 1 g',
    ),
  ]) {
    final isReference = example.isReference;
    testWidgets('shows ${example.expected} (new: ${example.isNew})', (
      tester,
    ) async {
      final grams = example.grams;
      final draft = MealIngredientsDraft(
        ingredient: IngredientDraft.draft(
          name: example.name,
          carbsPer100g: 20,
          fatPer100g: 0,
          fiberPer100g: 0,
          proteinPer100g: 0,
          nutritionConfidence: 0.75,
          isReference: isReference,
        ),
        ingredientPortion: IngredientPortionDraft(
          portion: isReference
              ? const PortionSelection.empty()
              : example.isNew
              ? PortionSelection.draft(name: example.portion, unitHint: 'g')
              : PortionSelection.existing(
                  id: 1,
                  name: example.portion,
                  unitHint: 'g',
                ),
          amount: grams,
        ),
        amount: 1,
        quantityConfidence: 0.75,
        entryType: 'planned',
        consumedAmount: null,
        consumedConfidence: null,
      );

      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MealIngredientReviewHeader(
              name: draft.ingredient.name,
              description: draft.measureDescription(gramsPerPortion: grams),
            ),
          ),
        ),
      );

      expect(find.text(example.name), findsOneWidget);
      expect(find.text(example.expected), findsOneWidget);
    });
  }
}
