import 'dart:async';

import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/copy_meal_source_controller.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_composition_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/meal_flow_test_fixture.dart';

void main() {
  for (final leavePage in [false, true]) {
    testWidgets('blocks saving while copying (leave page: $leavePage)', (
      tester,
    ) async {
      final completion = Completer<List<MealIngredientsDraft>>();
      final container = ProviderContainer(
        overrides: [
          getMealIngredientsDraftForMealProvider(
            1,
          ).overrideWith((_) => completion.future),
        ],
      );
      addTearDown(container.dispose);
      final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      final ingredient = mealFlowIngredient(container);
      container.read(mealDraftProvider.notifier).setMealIngredients([
        ingredient,
      ]);
      final before = container.read(mealDraftProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(home: const AddMealPage()),
        ),
      );
      await tester.pumpAndSettle();
      final saveButton = find.widgetWithText(FilledButton, 'Dalej: kiedy');
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
      final operation = container
          .read(copyMealSourceControllerProvider.notifier)
          .copyFromSource(
            CopiedMealFromMeal(
              id: 1,
              name: 'Source meal',
              date: DateTime(2026),
              copiedFromMealId: null,
              copiedFromTemplateId: null,
            ),
          );
      await tester.pump();
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(
        find.descendant(
          of: find.byType(MealCompositionStep),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      if (leavePage) await tester.pumpWidget(const SizedBox.shrink());
      completion.complete([ingredient]);
      expect(await operation, !leavePage);
      await tester.pumpAndSettle();
      if (leavePage) {
        expect(container.read(mealDraftProvider), same(before));
      } else {
        expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
        expect(
          find.descendant(
            of: find.byType(MealCompositionStep),
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
