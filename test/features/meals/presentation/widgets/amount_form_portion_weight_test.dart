import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/add_ingredients_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/amount_form.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
  const portion = PortionSelection.existing(
    id: 42,
    name: 'sztuka',
    unitHint: 'g',
  );

  for (final storedWeight in <double?>[null, 0, 150]) {
    testWidgets(
      'a selected portion requires its resolved weight ($storedWeight)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            portionsByIngredientByQueryProvider(
              41,
              '',
            ).overrideWith((_) async => []),
            gramsPerPortionProvider(
              ingredient,
              portion,
            ).overrideWith((_) async => storedWeight),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(mealIngredientsDraftProvider.notifier)
            .overrideMealIngredient(
              const MealIngredientsDraft(
                ingredient: ingredient,
                ingredientPortion: IngredientPortionDraft(
                  portion: portion,
                  amount: 0,
                ),
                amount: 2,
                quantityConfidence: 0.5,
                entryType: 'planned',
                consumedAmount: null,
                consumedConfidence: null,
              ),
            );
        container.read(mealIngredientAmountDraftProvider.notifier).setValue(2);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: const Scaffold(body: AmountForm()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          container
              .read(mealIngredientFormKeyProvider)
              .currentState!
              .validate(),
          storedWeight == 150,
        );
        if (storedWeight == 150) {
          expect(find.text('1 × sztuka = 150 g'), findsOneWidget);
          expect(find.textContaining('300 g'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
