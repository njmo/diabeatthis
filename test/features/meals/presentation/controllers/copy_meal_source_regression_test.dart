import 'dart:async';

import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/copy_meal_source_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CopiedMealFromMeal source(int id) => CopiedMealFromMeal(
    id: id,
    name: 'Meal $id',
    date: DateTime(2026, 11, 1),
    copiedFromMealId: null,
    copiedFromTemplateId: null,
  );
  test('late source cannot overwrite the latest selected meal', () async {
    final first = Completer<List<MealIngredientsDraft>>();
    final second = Completer<List<MealIngredientsDraft>>();
    final reads = <int>[];
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith(
          (ref) => throw StateError('Unexpected database read'),
        ),
        getMealIngredientsDraftForMealProvider(1).overrideWith((ref) {
          reads.add(1);
          return first.future;
        }),
        getMealIngredientsDraftForMealProvider(2).overrideWith((ref) {
          reads.add(2);
          return second.future;
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      copyMealSourceControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
    addTearDown(draftSubscription.close);
    await container.read(copyMealSourceControllerProvider.future);
    final controller = container.read(
      copyMealSourceControllerProvider.notifier,
    );
    final oldRequest = controller.copyFromSource(source(1));
    final newRequest = controller.copyFromSource(source(2));
    second.complete([]);
    expect(await newRequest, true);
    expect(container.read(mealDraftProvider).basedOnMealId, 2);
    first.complete([]);
    expect(await oldRequest, false);
    expect(container.read(mealDraftProvider).basedOnMealId, 2);
    expect(reads, [1, 2]);
    expect(container.read(copyMealSourceControllerProvider).hasError, false);
  });

  test(
    'cancelled source error does not replace current draft or controller state',
    () async {
      final response = Completer<List<MealIngredientsDraft>>();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
          getMealIngredientsDraftForMealProvider(
            1,
          ).overrideWith((ref) => response.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        copyMealSourceControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      await container.read(copyMealSourceControllerProvider.future);
      final original = container.read(mealDraftProvider);
      final controller = container.read(
        copyMealSourceControllerProvider.notifier,
      );
      final request = controller.copyFromSource(source(1));
      controller.cancelPendingCopy();
      expect(
        container.read(copyMealSourceControllerProvider).isLoading,
        false,
        reason:
            'An explicitly cancelled copy must not keep blocking meal saves',
      );
      response.completeError(StateError('Source disappeared'));
      expect(await request, false);
      expect(container.read(mealDraftProvider), original);
      expect(container.read(copyMealSourceControllerProvider).hasError, false);
    },
  );

  test(
    'active source failure is exposed and a subsequent request can recover',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
          getMealIngredientsDraftForMealProvider(
            1,
          ).overrideWith((ref) => throw StateError('Missing meal')),
          getMealIngredientsDraftForMealProvider(
            2,
          ).overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        copyMealSourceControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      await container.read(copyMealSourceControllerProvider.future);
      final controller = container.read(
        copyMealSourceControllerProvider.notifier,
      );
      await expectLater(controller.copyFromSource(source(1)), throwsStateError);
      expect(container.read(copyMealSourceControllerProvider).hasError, true);
      expect(await controller.copyFromSource(source(2)), true);
      expect(container.read(mealDraftProvider).basedOnMealId, 2);
      expect(container.read(copyMealSourceControllerProvider).hasValue, true);
    },
  );
}
