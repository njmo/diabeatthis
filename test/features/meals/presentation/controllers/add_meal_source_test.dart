import 'dart:async';

import 'package:diabeatthis/features/meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/copy_meal_source_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  final date = DateTime(2026, 9, 7);
  final sources = <CopiedMealType>[
    CopiedMealFromMeal(
      id: 10,
      name: 'Previous meal',
      date: date,
      copiedFromMealId: null,
      copiedFromTemplateId: null,
    ),
    CopiedMealFromMeal(
      id: 10,
      name: 'Previous meal copy',
      date: date,
      copiedFromMealId: 5,
      copiedFromTemplateId: 6,
    ),
    CopiedMealFromTemplate(
      id: 10,
      name: 'Template',
      date: date,
      copiedFromMealId: null,
    ),
    CopiedMealFromTemplate(
      id: 10,
      name: 'Template from meal',
      date: date,
      copiedFromMealId: 5,
    ),
  ];

  for (final source in sources) {
    for (final shouldFail in [false, true]) {
      test('copies ${source.name} atomically (failure: $shouldFail)', () async {
        final completion = Completer<List<MealIngredientsDraft>>();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            getMealIngredientsDraftForMealProvider(
              10,
            ).overrideWith((_) => completion.future),
            getMealIngredientsDraftForMealTemplateProvider(
              10,
            ).overrideWith((_) => completion.future),
          ],
        );
        addTearDown(container.dispose);
        final draftSubscription = container.listen(
          mealDraftProvider,
          (_, _) {},
        );
        addTearDown(draftSubscription.close);
        final controllerSubscription = container.listen(
          copyMealSourceControllerProvider,
          (_, _) {},
        );
        addTearDown(controllerSubscription.close);
        await container.read(copyMealSourceControllerProvider.future);
        final draft = container.read(mealDraftProvider.notifier);
        final originalIngredient = container.read(mealIngredientsDraftProvider);
        draft.setName('Current meal');
        draft.setPlannedAt(date);
        draft.setBasedOnMealId(98);
        draft.setMealTemplateId(99);
        draft.setMealIngredients([originalIngredient]);
        final before = container.read(mealDraftProvider);
        final updates = <MealDraft>[];
        final subscription = container.listen(
          mealDraftProvider,
          (_, next) => updates.add(next),
        );
        addTearDown(subscription.close);

        final operation = container
            .read(copyMealSourceControllerProvider.notifier)
            .copyFromSource(source);
        expect(container.read(mealDraftProvider), same(before));
        expect(updates, isEmpty);

        if (shouldFail) {
          final error = StateError('Could not load ingredients');
          final expectation = expectLater(operation, throwsA(same(error)));
          completion.completeError(error);
          await expectation;
          expect(container.read(mealDraftProvider), same(before));
          expect(updates, isEmpty);
        } else {
          final ingredients = [
            originalIngredient.copyWith(amount: 2),
            originalIngredient.copyWith(
              ingredient: originalIngredient.ingredient.copyWith(
                isReference: true,
              ),
              amount: 0.5,
            ),
          ];
          completion.complete(ingredients);
          await operation;
          expect(updates, hasLength(1));
          expect(
            updates.single,
            before.copyWith(
              name: source is CopiedMealFromTemplate
                  ? source.name
                  : before.name,
              mealIngredients: ingredients,
              mealTemplateId: source is CopiedMealFromTemplate
                  ? source.id
                  : source.copiedFromTemplateId,
              basedOnMealId: source is CopiedMealFromTemplate
                  ? source.copiedFromMealId
                  : source.copiedFromMealId ?? source.id,
            ),
          );
        }
      });
    }
  }
}
