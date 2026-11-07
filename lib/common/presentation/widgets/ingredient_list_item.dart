import 'package:flutter/material.dart';

import '../../../core/domain/model/ingredient.dart';
import 'ingredient_list_item_header.dart';
import 'ingredient_macro_chips.dart';

class IngredientListItem extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;

  const IngredientListItem({
    super.key,
    required this.ingredient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IngredientListItemHeader(ingredient: ingredient),
              const SizedBox(height: 12),
              IngredientMacroChips(ingredient: ingredient),
            ],
          ),
        ),
      ),
    );
  }
}
