import 'package:flutter/material.dart';

import '../../../../../core/domain/model/ingredient.dart';
import 'ingredient_empty_state.dart';
import 'ingredient_list_item.dart';
import 'ingredient_search_field.dart';

class IngredientListContent extends StatelessWidget {
  final List<Ingredient> ingredients;
  final TextEditingController queryController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<Ingredient> onIngredientTap;

  const IngredientListContent({
    super.key,
    required this.ingredients,
    required this.queryController,
    required this.query,
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
        if (ingredients.isEmpty)
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
