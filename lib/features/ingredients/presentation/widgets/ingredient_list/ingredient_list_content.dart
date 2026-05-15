import 'package:flutter/material.dart';

import '../../../../../common/widgets/search_text_field.dart';
import '../../../../../core/domain/model/ingredient.dart';
import 'ingredient_empty_state.dart';
import 'ingredient_list_item.dart';

class IngredientListContent extends StatelessWidget {
  final List<Ingredient> ingredients;
  final TextEditingController queryController;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  final VoidCallback? onLoadMore;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<Ingredient> onIngredientTap;

  const IngredientListContent({
    super.key,
    required this.ingredients,
    required this.queryController,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.hasError = false,
    this.onLoadMore,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onIngredientTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final isUserScroll =
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification;
        if (isUserScroll && notification.metrics.extentAfter < 120) {
          onLoadMore?.call();
        }
        return false;
      },
      child: CustomScrollView(
        cacheExtent: 0,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchTextField(
                    controller: queryController,
                    hintText: 'Szukaj po nazwie lub marce',
                    onChanged: onQueryChanged,
                    onClear: onClearQuery,
                  ),
                ],
              ),
            ),
          ),
          if (ingredients.isEmpty && isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (ingredients.isEmpty && hasError)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: TextButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                ),
              ),
            )
          else if (ingredients.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: IngredientEmptyState(),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
              sliver: SliverList.separated(
                itemCount: ingredients.length + (onLoadMore == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == ingredients.length) {
                    return _IngredientListTail(
                      isLoading: isLoadingMore,
                      hasMore: hasMore,
                      hasError: hasError,
                      onRetry: onLoadMore,
                    );
                  }

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
      ),
    );
  }
}

class _IngredientListTail extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final bool hasError;
  final VoidCallback? onRetry;

  const _IngredientListTail({
    required this.isLoading,
    required this.hasMore,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Spróbuj ponownie'),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox(height: 16);
    }

    return const SizedBox(height: 24);
  }
}
