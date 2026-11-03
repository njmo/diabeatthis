import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_filter_item.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_page_by_filter_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_list_filter.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_list_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/scripted_meal_dao.dart';
import '../../../../helpers/regression/scripted_meal_database.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  testWidgets(
    'latest query wins; clearing cancels pending search and resets pagination',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith(
            (ref) =>
                throw StateError('Filter state must not query the database'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        mealListControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(mealListControllerProvider.notifier);
      controller.loadNextPage();
      expect(
        container.read(mealListControllerProvider).visibleLimit,
        mealListPageSize * 2,
      );
      controller.setQuery('old');
      await tester.pump(const Duration(milliseconds: 200));
      controller.setQuery('  Rice  ');
      await tester.pump(const Duration(milliseconds: 299));
      expect(container.read(mealListControllerProvider).query, '');
      await tester.pump(const Duration(milliseconds: 1));
      expect(container.read(mealListControllerProvider).query, 'Rice');
      expect(
        container.read(mealListControllerProvider).visibleLimit,
        mealListPageSize,
      );
      controller.setQuery('must not appear');
      controller.setQuery('  ');
      await tester.pump(const Duration(seconds: 1));
      expect(container.read(mealListControllerProvider).query, '');
      controller.loadNextPage();
      controller.setIngredientFilterItems([
        const IngredientFilterItem(id: 9, name: 'Rice', removable: true),
        const IngredientFilterItem(id: 3, name: 'Potato', removable: true),
      ]);
      expect(container.read(mealListControllerProvider).filter.ingredientIds, [
        9,
        3,
      ]);
      expect(
        container.read(mealListControllerProvider).visibleLimit,
        mealListPageSize,
      );
    },
  );
  for (final scenario in <({MealListFilter filter, List<Object?> arguments})>[
    (filter: const MealListFilter.recent(), arguments: ['recent', 20, 'lunch']),
    (
      filter: const MealListFilter.byQuery(query: 'rice'),
      arguments: ['name', 'rice', 20, 'lunch'],
    ),
    (
      filter: const MealListFilter.byIngredients(
        ingredientIds: [1, 2, 3, 4, 5, 6, 7],
      ),
      arguments: [
        'ingredients',
        [1, 2, 3, 4, 5, 6],
        20,
        'lunch',
      ],
    ),
    (
      filter: const MealListFilter.byQueryAndIngredients(
        query: 'rice',
        ingredientIds: [1, 2, 3, 4, 5, 6, 7],
      ),
      arguments: [
        'combined',
        'rice',
        [1, 2, 3, 4, 5, 6],
        20,
        'lunch',
      ],
    ),
  ]) {
    test(
      'meal list read preserves category, limit and selected identities: ${scenario.arguments.first}',
      () async {
        final reads = ScriptedRead<List<MealData>>('meal list', [
          (
            arguments: scenario.arguments,
            respond: () => [
              const MealData(
                id: 17,
                name: 'Historical rice',
                plannedAt: 1000,
                purpose: 'meal',
                status: 'eaten',
                createdAt: 1000,
                updatedAt: 1000,
                isSynced: false,
              ),
            ],
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(
              ScriptedMealDatabase(ScriptedMealDao(reads)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final provider = mealListWindowProvider(
          filter: scenario.filter,
          limit: 20,
          category: 'lunch',
        );
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        final results = await container.read(provider.future);
        expect(results.map((meal) => meal.id), [17]);
        expect(results.single.name, 'Historical rice');
        reads.verifyComplete();
      },
    );
  }
}
