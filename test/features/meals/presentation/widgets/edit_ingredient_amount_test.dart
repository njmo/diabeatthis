import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/amount_form.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/confidence_slider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
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
            portionsByIngredientByQueryProvider(
              1,
              '',
            ).overrideWith((_) async => []),
          ],
        );
        addTearDown(container.dispose);
        final draft = container.read(mealIngredientsDraftProvider);
        final original = draft.copyWith(
          ingredient: IngredientDraft.existing(
            id: 1,
            name: '',
            isReference: isReference,
            carbsPer100g: 20,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: draft.ingredient.nutritionConfidence,
          ),
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
        expect(
          find.text('Dodaj w gramach'),
          isReference ? findsNothing : findsOneWidget,
        );
        if (!isReference) {
          await tester.tap(find.text('Dodaj w gramach'));
          await tester.pumpAndSettle();
          expect(find.text('Dodaj w gramach'), findsOneWidget);
          await tester.tap(find.text('Dodaj w gramach'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FriendlyAmountSelector>(
                  find.byType(FriendlyAmountSelector),
                )
                .value,
            50,
          );
        }
        expect(find.text('Dalej'), findsNothing);
        expect(find.text('Podsumowanie'), findsOneWidget);
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .onChanged(0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Podsumowanie'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(AmountForm), findsOneWidget);

        final updatedAmount = isReference ? 2.0 : 100.0;
        await tester.ensureVisible(
          find.widgetWithText(ActionChip, isReference ? '+2 porcje' : '+100 g'),
        );
        await tester.tap(
          find.widgetWithText(ActionChip, isReference ? '+2 porcje' : '+100 g'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MealIngredientReview), findsNothing);
        expect(container.read(mealIngredientsDraftProvider), original);
        await tester.tap(find.text('Podsumowanie'));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(MealIngredientReview), findsOneWidget);
        expect(find.text('Łączna pewność'), findsOneWidget);
        expect(find.text(isReference ? '40 g' : '20 g'), findsOneWidget);
        await tester.tap(find.text('Dodaj składnik'));
        await tester.pumpAndSettle();
        expect(result, original.copyWith(amount: updatedAmount));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
