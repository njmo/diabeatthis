import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/compact_clear_button.dart';
import '../../data/models/ingredient_filter_item.dart';

class SelectedIngredientChips extends StatelessWidget {
  final List<IngredientFilterItem> ingredients;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onClearAll;

  const SelectedIngredientChips({
    super.key,
    required this.ingredients,
    required this.onRemove,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final hasClearButton = onClearAll != null && ingredients.isNotEmpty;
    final itemCount = ingredients.length + (hasClearButton ? 1 : 0);

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          if (hasClearButton && index == 0) {
            return Center(
              child: CompactClearButton(
                tooltip: context.lang.ingredientClearAllTooltip,
                onPressed: onClearAll!,
                size: 24,
                iconSize: 14,
              ),
            );
          }

          final ingredientIndex = hasClearButton ? index - 1 : index;
          final ingredient = ingredients[ingredientIndex];
          final onRemove = this.onRemove;
          if (onRemove == null || !ingredient.removable) {
            return Chip(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(ingredient.name),
            );
          }

          return ActionChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(ingredient.name),
            onPressed: () {
              onRemove(ingredient.id);
            },
          );
        },
      ),
    );
  }
}
