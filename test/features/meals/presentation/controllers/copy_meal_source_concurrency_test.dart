import 'dart:async';

import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/add_meal_controller.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/copy_meal_source_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  CopiedMealType source(int id) => CopiedMealFromMeal(
    id: id,
    name: 'Meal $id',
    date: DateTime(2026),
    copiedFromMealId: null,
    copiedFromTemplateId: null,
  );

  for (final oldFinishesFirst in [false, true]) {
    for (final oldFails in [false, true]) {
      test(
        'ignores stale result (first: $oldFinishesFirst, error: $oldFails)',
        () async {
          final oldCompletion = Completer<List<MealIngredientsDraft>>();
          final newCompletion = Completer<List<MealIngredientsDraft>>();
          final container = ProviderContainer(
            retry: (_, _) => null,
            overrides: [
              getMealIngredientsDraftForMealProvider(
                1,
              ).overrideWith((_) => oldCompletion.future),
              getMealIngredientsDraftForMealProvider(
                2,
              ).overrideWith((_) => newCompletion.future),
            ],
          );
          addTearDown(container.dispose);
          final subscription = container.listen(
            copyMealSourceControllerProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          final draftSubscription = container.listen(
            mealDraftProvider,
            (_, _) {},
          );
          addTearDown(draftSubscription.close);
          final controller = container.read(
            copyMealSourceControllerProvider.notifier,
          );
          final before = container.read(mealDraftProvider);
          final oldOperation = controller.copyFromSource(source(1));
          final newOperation = controller.copyFromSource(source(2));
          expect(
            container.read(copyMealSourceControllerProvider).isLoading,
            isTrue,
          );
          await expectLater(
            container.read(addMealControllerProvider.notifier).addMeal(before),
            throwsStateError,
          );

          Future<void> finishOld() async {
            if (oldFails) {
              oldCompletion.completeError(StateError('Old request failed'));
            } else {
              oldCompletion.complete([]);
            }
            expect(await oldOperation, isFalse);
          }

          if (oldFinishesFirst) {
            await finishOld();
            expect(
              container.read(copyMealSourceControllerProvider).isLoading,
              isTrue,
            );
            expect(container.read(mealDraftProvider), same(before));
          }
          newCompletion.complete([]);
          expect(await newOperation, isTrue);
          expect(
            container.read(copyMealSourceControllerProvider).isLoading,
            isFalse,
          );
          expect(container.read(mealDraftProvider).basedOnMealId, 2);
          if (!oldFinishesFirst) await finishOld();
          expect(container.read(mealDraftProvider).basedOnMealId, 2);
          expect(
            container.read(copyMealSourceControllerProvider).hasError,
            isFalse,
          );
        },
      );
    }
  }

  test('ignores old success after newest request fails', () async {
    final oldCompletion = Completer<List<MealIngredientsDraft>>();
    final newCompletion = Completer<List<MealIngredientsDraft>>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        getMealIngredientsDraftForMealProvider(
          1,
        ).overrideWith((_) => oldCompletion.future),
        getMealIngredientsDraftForMealProvider(
          2,
        ).overrideWith((_) => newCompletion.future),
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
    final before = container.read(mealDraftProvider);
    final controller = container.read(
      copyMealSourceControllerProvider.notifier,
    );
    final oldOperation = controller.copyFromSource(source(1));
    final newOperation = controller.copyFromSource(source(2));
    final error = StateError('Latest request failed');
    final expectation = expectLater(newOperation, throwsA(same(error)));
    newCompletion.completeError(error);
    await expectation;
    expect(container.read(copyMealSourceControllerProvider).isLoading, isFalse);
    oldCompletion.complete([]);
    expect(await oldOperation, isFalse);
    expect(container.read(mealDraftProvider), same(before));
    expect(container.read(copyMealSourceControllerProvider).error, same(error));
  });

  test(
    'keeps copying when a screen subscription is temporarily paused',
    () async {
      final completion = Completer<List<MealIngredientsDraft>>();
      final container = ProviderContainer(
        overrides: [
          getMealIngredientsDraftForMealProvider(
            1,
          ).overrideWith((_) => completion.future),
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
      final operation = container
          .read(copyMealSourceControllerProvider.notifier)
          .copyFromSource(source(1));
      subscription.pause();
      completion.complete([]);
      expect(await operation, isTrue);
      subscription.resume();
      expect(
        container.read(copyMealSourceControllerProvider).isLoading,
        isFalse,
      );
      expect(container.read(mealDraftProvider).basedOnMealId, 1);
    },
  );

  for (final fails in [false, true]) {
    test('ignores response after leaving editor (error: $fails)', () async {
      final completion = Completer<List<MealIngredientsDraft>>();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          getMealIngredientsDraftForMealProvider(
            1,
          ).overrideWith((_) => completion.future),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        copyMealSourceControllerProvider,
        (_, _) {},
      );
      final draftSubscription = container.listen(mealDraftProvider, (_, _) {});
      addTearDown(draftSubscription.close);
      final before = container.read(mealDraftProvider);
      final operation = container
          .read(copyMealSourceControllerProvider.notifier)
          .copyFromSource(source(1));
      container
          .read(copyMealSourceControllerProvider.notifier)
          .cancelPendingCopy();
      subscription.close();
      if (fails) {
        completion.completeError(StateError('Request failed after leaving'));
      } else {
        completion.complete([]);
      }
      expect(await operation, isFalse);
      expect(container.read(mealDraftProvider), same(before));
    });
  }
}
