import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

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
    final normalizedQuery = query.value.trim();
    final searchResults = normalizedQuery.isEmpty
        ? null
        : ref.watch(ingredientsByQueryProvider(normalizedQuery));
    final pagingController = useMemoized(
      () => PagingController<int, Ingredient>(
        getNextPageKey: _nextPageKey,
        fetchPage: (pageKey) =>
            ref.read(ingredientListPageProvider(pageKey).future),
      ),
      const [],
    );
    useEffect(() => pagingController.dispose, [pagingController]);

    return SafeArea(
      child: searchResults == null
          ? PagingListener(
              controller: pagingController,
              builder: (context, state, fetchNextPage) {
                return IngredientListContent(
                  ingredients: const [],
                  queryController: queryController,
                  query: query.value,
                  pagingState: state,
                  fetchNextPage: fetchNextPage,
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
                query: query.value,
                isLoading: true,
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
                  query: query.value,
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

int? _nextPageKey(PagingState<int, Ingredient> state) {
  final pages = state.pages;
  if (pages != null &&
      pages.isNotEmpty &&
      pages.last.length < ingredientListPageSize) {
    return null;
  }
  final keys = state.keys;
  return keys == null || keys.isEmpty ? 0 : keys.last + 1;
}

void _openIngredientDetails(BuildContext context, Ingredient ingredient) {
  ingredient.mapOrNull(
    existing: (data) {
      context.router.push(routes.IngredientRoute(ingredientId: data.id));
    },
  );
}
