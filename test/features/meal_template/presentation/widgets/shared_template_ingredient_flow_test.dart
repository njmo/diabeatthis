import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/meal_template/data/provider/meal_template_draft_provider.dart';
import 'package:diabeatthis/features/meal_template/presentation/widgets/meal_template_ingredients_list_editor.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'template receives the shared sheet result only after the common summary',
    (tester) async {
      final lang = AppLocalizationsPl();
      const ingredient = Ingredient(
        id: 51,
        name: 'Reference lunch',
        carbsPer100g: 40,
        fatPer100g: 10,
        fiberPer100g: 0,
        proteinPer100g: 25,
        nutritionConfidence: 0.75,
        isReference: true,
        iconAssetPath: 'assets/icons/food/prepared_meal.png',
      );
      final container = ProviderContainer(
        overrides: [
          ingredientsByQueryProvider(
            '',
          ).overrideWith((_) async => [ingredient]),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(
              body: SingleChildScrollView(
                child: MealTemplateIngredientsListEditor(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_box));
      await tester.pumpAndSettle();
      expect(find.byType(AddMealIngredient), findsOneWidget);

      await tester.tap(find.text('Reference lunch'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(lang.ingredientSelectNamed('Reference lunch')),
      );
      await tester.pumpAndSettle();
      tester
          .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
          .onChanged(1.5);
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.ingredientReviewAmount));
      await tester.pumpAndSettle();

      expect(find.byType(MealIngredientReview), findsOneWidget);
      expect(
        container.read(mealTemplateDraftProvider).mealIngredients,
        isEmpty,
      );
      await tester.tap(find.text(lang.addIngredientTitle));
      await tester.pumpAndSettle();

      expect(find.byType(AddMealIngredient), findsNothing);
      final result = container
          .read(mealTemplateDraftProvider)
          .mealIngredients
          .single;
      expect(result.ingredient.name, 'Reference lunch');
      expect(result.ingredient.nutritionConfidence, 0.75);
      expect(result.defaultAmount, 1.5);
      expect(result.quantityConfidence, 0.5);
      expect(
        result.ingredientPortion.portion.maybeMap(
          empty: (_) => true,
          orElse: () => false,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
