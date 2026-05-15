import 'package:flutter/material.dart';

import '../../../../common/widgets/compact_clear_button.dart';
import '../../../../core/domain/model/ingredient.dart';

enum SelectedIngredientChipsVariant {
  mealList(clearButtonSize: 26, clearButtonIconSize: 14),
  sheet(clearButtonSize: 24, clearButtonIconSize: 14);

  final double clearButtonSize;
  final double clearButtonIconSize;

  const SelectedIngredientChipsVariant({
    required this.clearButtonSize,
    required this.clearButtonIconSize,
  });
}

class SelectedIngredientChips extends StatelessWidget {
  final List<Ingredient> ingredients;
  final ValueChanged<int> onRemove;
  final VoidCallback? onClearAll;
  final SelectedIngredientChipsVariant variant;

  const SelectedIngredientChips({
    super.key,
    required this.ingredients,
    required this.onRemove,
    this.onClearAll,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onClearAll != null && ingredients.isNotEmpty)
          CompactClearButton(
            tooltip: 'Usuń wszystkie składniki',
            onPressed: onClearAll!,
            size: variant.clearButtonSize,
            iconSize: variant.clearButtonIconSize,
          ),
        for (final ingredient in ingredients)
          ActionChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            label: Text(_ingredientName(ingredient)),
            onPressed: () {
              final ingredientId = ingredientIdOf(ingredient);
              if (ingredientId != null) {
                onRemove(ingredientId);
              }
            },
          ),
      ],
    );
  }
}

int? ingredientIdOf(Ingredient ingredient) {
  return ingredient.mapOrNull(existing: (value) => value.id);
}

String _ingredientName(Ingredient ingredient) {
  return ingredient.map(
    existing: (value) => value.name,
    draft: (value) => value.name,
  );
}
