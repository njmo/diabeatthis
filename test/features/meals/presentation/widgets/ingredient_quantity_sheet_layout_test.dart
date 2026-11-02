import 'package:diabeatthis/common/widgets/amount_entry_dialog.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final isReference in [false, true]) {
    for (final textScale in [1.0, 1.5]) {
      testWidgets(
        'quantity and review remain usable on a small phone (reference: $isReference, text scale: $textScale)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final initial = container.read(mealIngredientsDraftProvider);
          final draft = initial.copyWith(
            ingredient: initial.ingredient.copyWith(
              name: 'A long ingredient name that can wrap',
              isReference: isReference,
              carbsPer100g: 20,
              proteinPer100g: 4,
              fatPer100g: 2,
              iconAssetPath: 'assets/icons/food/prepared_meal.png',
            ),
            ingredientPortion: const IngredientPortionDraft(
              portion: PortionSelection.empty(),
              amount: 1,
            ),
            amount: 99999.5,
          );
          MealIngredientsDraft? result;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: localizedMaterialApp(
                home: Scaffold(
                  body: Consumer(
                    builder: (context, ref, _) {
                      return TextButton(
                        onPressed: () async {
                          result = await showAddMealIngredientSheet(
                            context: context,
                            ref: ref,
                            initialDraft: draft,
                          );
                        },
                        child: const Text('Open'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final amountLabel = find.descendant(
            of: find.byType(FriendlyAmountSelector),
            matching: find.textContaining('99999,5'),
          );
          await tester.ensureVisible(amountLabel);
          await tester.tap(amountLabel);
          await tester.pumpAndSettle();
          expect(find.byType(AmountEntryDialog), findsOneWidget);
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField),
            isReference ? '1,5' : '225',
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Podsumowanie'));
          await tester.pumpAndSettle();
          expect(find.byType(MealIngredientReview), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Dodaj składnik'));
          await tester.pumpAndSettle();
          expect(result?.amount, isReference ? 1.5 : 225);
          expect(result?.ingredient, draft.ingredient);
        },
      );
    }
  }
}
