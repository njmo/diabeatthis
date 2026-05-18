import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/ingredient.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_list/ingredient_list_content.dart';

class IngredientList extends HookConsumerWidget {
  const IngredientList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final query = useState('');
    final visibleLimit = useState(ingredientListPageSize);
    final normalizedQuery = query.value.trim();
    final searchResults = normalizedQuery.isEmpty
        ? null
        : ref.watch(ingredientsByQueryStreamProvider(normalizedQuery));
    final ingredientsState = ref.watch(ingredientListStreamProvider);

    return SafeArea(
      child: searchResults == null
          ? ingredientsState.when(
              loading: () => IngredientListContent(
                ingredients: const [],
                queryController: queryController,
                isLoading: true,
                hasMore: false,
                onQueryChanged: (value) => query.value = value,
                onClearQuery: () {
                  queryController.clear();
                  query.value = '';
                },
                onIngredientTap: (ingredient) {
                  _openIngredientDetails(context, ingredient);
                },
              ),
              error: (error, _) => IngredientListContent(
                ingredients: const [],
                queryController: queryController,
                hasMore: false,
                hasError: true,
                onLoadMore: () => ref.invalidate(ingredientListStreamProvider),
                onQueryChanged: (value) => query.value = value,
                onClearQuery: () {
                  queryController.clear();
                  query.value = '';
                },
                onIngredientTap: (ingredient) {
                  _openIngredientDetails(context, ingredient);
                },
              ),
              data: (ingredients) {
                final visibleIngredients = ingredients
                    .take(visibleLimit.value)
                    .toList(growable: false);
                final hasMore = visibleIngredients.length < ingredients.length;

                void loadNextPage() {
                  if (!hasMore) {
                    return;
                  }
                  visibleLimit.value += ingredientListPageSize;
                }

                return IngredientListContent(
                  ingredients: visibleIngredients,
                  queryController: queryController,
                  hasMore: hasMore,
                  onLoadMore: loadNextPage,
                  onQueryChanged: (value) => query.value = value,
                  onClearQuery: () {
                    queryController.clear();
                    query.value = '';
                  },
                  onIngredientTap: (ingredient) {
                    _openIngredientDetails(context, ingredient);
                  },
                );
              },
            )
          : searchResults.when(
              loading: () => IngredientListContent(
                ingredients: const [],
                queryController: queryController,
                isLoading: true,
                hasMore: false,
                onQueryChanged: (value) => query.value = value,
                onClearQuery: () {
                  queryController.clear();
                  query.value = '';
                },
                onIngredientTap: (ingredient) {
                  _openIngredientDetails(context, ingredient);
                },
              ),
              error: (e, st) =>
                  Center(child: Text('Nie udało się wczytać: $e')),
              data: (items) {
                return IngredientListContent(
                  ingredients: items,
                  queryController: queryController,
                  hasMore: false,
                  onQueryChanged: (value) => query.value = value,
                  onClearQuery: () {
                    queryController.clear();
                    query.value = '';
                  },
                  onIngredientTap: (ingredient) {
                    _openIngredientDetails(context, ingredient);
                  },
                );
              },
            ),
    );
  }
}

void _openIngredientDetails(BuildContext context, Ingredient ingredient) {
  context.router.push(routes.IngredientRoute(ingredientId: ingredient.id));
}
