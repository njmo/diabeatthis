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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
