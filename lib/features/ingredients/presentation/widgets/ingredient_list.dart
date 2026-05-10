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
    final ingredients = ref.watch(ingredientsStreamProvider);

    return SafeArea(
      child: ingredients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Nie udało się wczytać: $e')),
        data: (items) {
          final filtered = _filterIngredients(items, query.value);

          return IngredientListContent(
            ingredients: filtered,
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

void _openIngredientDetails(BuildContext context, Ingredient ingredient) {
  ingredient.mapOrNull(
    existing: (data) {
      context.router.push(routes.IngredientRoute(ingredientId: data.id));
    },
  );
}

List<Ingredient> _filterIngredients(List<Ingredient> items, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return items;
  }

  return items.where((ingredient) {
    final brand = ingredient.brand?.toLowerCase() ?? '';
    return ingredient.name.toLowerCase().contains(normalizedQuery) ||
        brand.contains(normalizedQuery);
  }).toList();
}
