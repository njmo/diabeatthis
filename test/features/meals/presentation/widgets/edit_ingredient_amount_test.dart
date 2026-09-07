import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/confidence_slider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final isReference in [false, true]) {
    testWidgets(
      'preserves edited amount and confidence (reference: $isReference)',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            portionsByQueryProvider('').overrideWith((_) async => []),
          ],
        );
        addTearDown(container.dispose);
        final draft = container.read(mealIngredientsDraftProvider);
        final original = draft.copyWith(
          ingredient: draft.ingredient.copyWith(isReference: isReference),
          ingredientPortion: const IngredientPortionDraft(
            portion: PortionSelection.empty(),
            amount: 1,
          ),
          amount: isReference ? 0.5 : 50,
          quantityConfidence: 0.8,
        );
        MealIngredientsDraft? result;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () async =>
                        result = await showAddMealIngredientSheet(
                          context: context,
                          ref: ref,
                          initialDraft: original,
                        ),
                    child: const Text('Edit'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        if (!isReference) {
          await tester.tap(find.text('Dodaj w gramach'));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<FriendlyAmountSelector>(
                find.byType(FriendlyAmountSelector),
              )
              .value,
          original.amount,
        );
        expect(
          tester.widget<ConfidenceSlider>(find.byType(ConfidenceSlider)).value,
          ConfidenceLevel.high,
        );
        expect(container.read(mealIngredientsDraftProvider), original);
        await tester.tap(find.text('Dalej'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dodaj'));
        await tester.pumpAndSettle();
        expect(result, original);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
