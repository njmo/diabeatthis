import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/domain/model/ingredient.dart';
import '../../../../features/ingredients/presentation/widgets/ingredient_list/ingredient_empty_state.dart';
import '../../../l10n/language.dart';
import '../../../widgets/search_text_field.dart';
import '../../widgets/ingredient_list_item.dart';
import '../controllers/ingredients_controller.dart';
import 'ingredient_list_tail.dart';

class IngredientListContent extends StatelessWidget {
  final List<Ingredient> ingredients;
  final TextEditingController queryController;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  final VoidCallback? onLoadMore;
  final ValueChanged<String> onQueryChanged;
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
    required this.onIngredientTap,
  });

  IngredientListContent.controlled({
    super.key,
    required IngredientsController controller,
    required this.queryController,
    required this.onQueryChanged,
  }) : ingredients = controller.state.items,
       isLoading = controller.state.loading,
       isLoadingMore = controller.state.loadingMore,
       hasMore = controller.state.hasMore,
       hasError = controller.state.failed,
       onLoadMore = controller.state.failed
           ? controller.retry
           : controller.state.hasMore
           ? controller.loadMore
           : null,
       onIngredientTap = controller.open ?? ((_) {});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 112 + MediaQuery.paddingOf(context).bottom;

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
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchTextField(
                    controller: queryController,
                    hintText: context.lang.ingredientSearchByNameOrBrand,
                    onChanged: onQueryChanged,
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
                  label: Text(context.lang.commonRetry),
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
                    return IngredientListTail(
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
