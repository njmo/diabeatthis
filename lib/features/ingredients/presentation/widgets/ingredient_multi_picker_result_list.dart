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
              final data = ingredient.mapOrNull(existing: (e) => e);
              if (data == null) {
                return const SizedBox.shrink();
              }
              final selected = selectedIngredientIds.contains(data.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  selected ? Icons.check_circle : Icons.add_circle_outline,
                ),
                title: Text(data.name),
                subtitle: Text(
                  '${data.kcalPer100g?.round() ?? '-'} kcal / 100 g',
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
