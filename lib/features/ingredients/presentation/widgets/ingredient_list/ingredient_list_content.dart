import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../core/domain/model/ingredient.dart';
import 'ingredient_empty_state.dart';
import 'ingredient_list_item.dart';
import 'ingredient_search_field.dart';

class IngredientListContent extends StatelessWidget {
  final List<Ingredient> ingredients;
  final TextEditingController queryController;
  final String query;
  final PagingState<int, Ingredient>? pagingState;
  final NextPageCallback? fetchNextPage;
  final bool isLoading;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<Ingredient> onIngredientTap;

  const IngredientListContent({
    super.key,
    required this.ingredients,
    required this.queryController,
    required this.query,
    this.pagingState,
    this.fetchNextPage,
    this.isLoading = false,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onIngredientTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IngredientSearchField(
                  controller: queryController,
                  query: query,
                  onChanged: onQueryChanged,
                  onClear: onClearQuery,
                ),
              ],
            ),
          ),
        ),
        if (pagingState != null && fetchNextPage != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: PagedSliverList<int, Ingredient>.separated(
              state: pagingState!,
              fetchNextPage: fetchNextPage!,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              builderDelegate: PagedChildBuilderDelegate<Ingredient>(
                itemBuilder: (context, ingredient, index) {
                  return IngredientListItem(
                    ingredient: ingredient,
                    onTap: () => onIngredientTap(ingredient),
                  );
                },
                firstPageProgressIndicatorBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
                newPageProgressIndicatorBuilder: (_) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                noItemsFoundIndicatorBuilder: (_) =>
                    const IngredientEmptyState(),
                firstPageErrorIndicatorBuilder: (_) => const Center(
                  child: Text('Nie udało się wczytać składników'),
                ),
                newPageErrorIndicatorBuilder: (_) => Center(
                  child: TextButton.icon(
                    onPressed: fetchNextPage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Spróbuj ponownie'),
                  ),
                ),
                noMoreItemsIndicatorBuilder: (_) => const SizedBox(height: 16),
              ),
            ),
          )
        else if (ingredients.isEmpty && isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ingredients.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: IngredientEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                return IngredientListItem(
                  ingredient: ingredient,
                  onTap: () => onIngredientTap(ingredient),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
            ),
          ),
      ],
    );
  }
}
