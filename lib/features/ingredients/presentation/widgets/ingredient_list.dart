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
    final normalizedQuery = query.value.trim();
    final searchResults = normalizedQuery.isEmpty
        ? null
        : ref.watch(ingredientsByQueryProvider(normalizedQuery));
    final ingredients = useState<List<Ingredient>>(const []);
    final nextPage = useState(0);
    final isLoading = useState(false);
    final hasMore = useState(true);
    final error = useState<Object?>(null);

    Future<void> loadNextPage() async {
      if (isLoading.value || !hasMore.value) {
        return;
      }

      isLoading.value = true;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!context.mounted) return;

        final page = await ref.read(
          ingredientListPageProvider(nextPage.value).future,
        );
        if (!context.mounted) return;

        ingredients.value = [...ingredients.value, ...page];
        nextPage.value += 1;
        hasMore.value = page.length == ingredientListPageSize;
        error.value = null;
      } catch (e) {
        if (!context.mounted) return;
        error.value = e;
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    useEffect(() {
      loadNextPage();
      return null;
    }, const []);

    return SafeArea(
      child: searchResults == null
          ? IngredientListContent(
              ingredients: ingredients.value,
              queryController: queryController,
              query: query.value,
              isLoading: isLoading.value && ingredients.value.isEmpty,
              isLoadingMore: isLoading.value && ingredients.value.isNotEmpty,
              hasMore: hasMore.value,
              hasError: error.value != null,
              onLoadMore: loadNextPage,
              onQueryChanged: (value) => query.value = value,
              onClearQuery: () {
                queryController.clear();
                query.value = '';
              },
              onIngredientTap: (ingredient) {
                _openIngredientDetails(context, ingredient);
              },
            )
          : searchResults.when(
              loading: () => IngredientListContent(
                ingredients: const [],
                queryController: queryController,
                query: query.value,
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
                  query: query.value,
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
  ingredient.mapOrNull(
    existing: (data) {
      context.router.push(routes.IngredientRoute(ingredientId: data.id));
    },
  );
}
