import 'package:diabeatthis/features/ingredients/data/icons/ingredient_icon_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  testWidgets(
    'review retains the suggested icon before ingredient persistence',
    (tester) async {
      const path = 'assets/icons/food/prepared_meal.png';
      final container = ProviderContainer(
        overrides: [
          ingredientIconSuggestionProvider((
            'Oatmeal',
            null,
          )).overrideWith((_) async => path),
        ],
      );
      addTearDown(container.dispose);
      final draft = mealFlowIngredient(container);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealIngredientReviewContent(
                  draft: draft.copyWith(
                    ingredient: draft.ingredient.copyWith(iconAssetPath: null),
                  ),
                  gramsPerPortion: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<IngredientIcon>(find.byType(IngredientIcon)).assetPath,
        path,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
