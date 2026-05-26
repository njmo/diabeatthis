import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/ingredient.dart';

class IngredientMultiPickerResultList extends StatelessWidget {
  final AsyncValue<List<Ingredient>> ingredients;
  final Set<int> selectedIngredientIds;
  final ValueChanged<Ingredient> onToggleIngredient;

  const IngredientMultiPickerResultList({
    super.key,
    required this.ingredients,
    required this.selectedIngredientIds,
    required this.onToggleIngredient,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ingredients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Nie udało się wczytać składników: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Brak składników'));
          }
          return ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ingredient = items[index];
              final selected = selectedIngredientIds.contains(ingredient.id);
              final brand = ingredient.brand?.trim();
              final brandLabel = brand == null || brand.isEmpty
                  ? 'Bez marki'
                  : brand;
              final kcalLabel = ingredient.kcalPer100g?.round() ?? '-';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected ? Icons.check_circle : Icons.add_circle_outline,
                ),
                title: Text(ingredient.name),
                subtitle: Text(
                  '$brandLabel • $kcalLabel kcal / 100 g',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onToggleIngredient(ingredient),
              );
            },
          );
        },
      ),
    );
  }
}
